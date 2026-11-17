package sidepot

import (
	"context"
	"fmt"

	pb "github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/gen/sidepot/v1"
)

// gameState is the game as game_state reports it.
type gameState struct {
	L1Height      uint32 `json:"l1_height"`
	Clock         uint32 `json:"clock"`
	Round         uint32 `json:"round"`
	Deadline      uint32 `json:"deadline"`
	PriceSats     uint64 `json:"price_sats"`
	PotSats       uint64 `json:"pot_sats"`
	BonusPoolSats uint64 `json:"bonus_pool_sats"`
	Accounts      uint32 `json:"accounts"`
}

func (g *gameState) proto() *pb.GameState {
	if g == nil {
		return nil
	}
	return &pb.GameState{
		L1Height:      g.L1Height,
		Clock:         g.Clock,
		Round:         g.Round,
		Deadline:      g.Deadline,
		PriceSats:     g.PriceSats,
		PotSats:       g.PotSats,
		BonusPoolSats: g.BonusPoolSats,
		Accounts:      g.Accounts,
	}
}

type gameAccount struct {
	BalanceSats uint64 `json:"balance_sats"`
	Keys        uint64 `json:"keys"`
	Nonce       uint64 `json:"nonce"`
}

func (a *gameAccount) proto() *pb.GameAccount {
	if a == nil {
		return nil
	}
	return &pb.GameAccount{BalanceSats: a.BalanceSats, Keys: a.Keys, Nonce: a.Nonce}
}

// gameMove is what the node returns for an entry it posted.
type gameMove struct {
	Txid string `json:"txid"`
	// Entry is the signed move in hex, set when the node only signed it.
	Entry   string `json:"entry"`
	Round   uint32 `json:"round"`
	Nonce   uint64 `json:"nonce"`
	Expires uint32 `json:"expires"`
}

func (m gameMove) proto() *pb.GameMoveResponse {
	return &pb.GameMoveResponse{Txid: m.Txid, Round: m.Round, Nonce: m.Nonce, Expires: m.Expires}
}

func (h *Handler) GetGameState(ctx context.Context, req *pb.GetGameStateRequest) (*pb.GetGameStateResponse, error) {
	var state *struct {
		gameState
		StartHeight uint32     `json:"start_height"`
		Preview     *gameState `json:"preview"`
	}
	if err := h.proxy.Client.Call(ctx, "game_state", nil, &state); err != nil {
		return nil, err
	}
	if state == nil {
		return &pb.GetGameStateResponse{}, nil
	}
	return &pb.GetGameStateResponse{
		Confirmed:   state.gameState.proto(),
		Preview:     state.Preview.proto(),
		StartHeight: state.StartHeight,
	}, nil
}

func (h *Handler) GetGameAccount(ctx context.Context, req *pb.GetGameAccountRequest) (*pb.GetGameAccountResponse, error) {
	var account struct {
		gameAccount
		Key     string       `json:"key"`
		Address string       `json:"address"`
		Preview *gameAccount `json:"preview"`
	}
	if err := h.proxy.Client.Call(ctx, "game_my_account", nil, &account); err != nil {
		return nil, err
	}
	return &pb.GetGameAccountResponse{
		Key:       account.Key,
		Address:   account.Address,
		Confirmed: account.gameAccount.proto(),
		Preview:   account.Preview.proto(),
	}, nil
}

// Slot is Sidepot's BIP300 slot.
const Slot = 88

// defaultMoveFeeSats pays for the mainchain transaction that carries a move.
const defaultMoveFeeSats = 1000

// L1Wallet is the mainchain wallet that carries game moves and deposits. The
// orchestrator's own wallet serves it in full and in light mode alike, so the
// user plays from the coins BitWindow shows.
type L1Wallet interface {
	// SendData broadcasts a transaction with one zero-value OP_RETURN output
	// holding the data in a single push, and returns its txid.
	SendData(ctx context.Context, dataHex string, feeSats int64) (string, error)
	// Deposit broadcasts a BIP300 deposit to the slot for the given
	// destination text, and returns its txid.
	Deposit(ctx context.Context, slot uint8, destination string, amountSats, feeSats int64) (string, error)
}

// SetL1Wallet makes the handler post moves and deposits through wallet. The
// node then only signs: its own enforcer needs no wallet, and in light mode
// has none.
func (h *Handler) SetL1Wallet(wallet L1Wallet) {
	h.l1 = wallet
}

func moveFee(fee *uint64) int64 {
	if fee == nil || *fee == 0 {
		return defaultMoveFeeSats
	}
	return int64(*fee)
}

// post sends a move the node signed and fills in its txid.
func (h *Handler) post(ctx context.Context, move *gameMove, fee *uint64) error {
	if move.Entry == "" {
		return fmt.Errorf("the sidepot node returned no signed entry; it needs version 0.1.2 or later")
	}
	txid, err := h.l1.SendData(ctx, move.Entry, moveFee(fee))
	if err != nil {
		return err
	}
	move.Txid = txid
	return nil
}

func (h *Handler) GameBuy(ctx context.Context, req *pb.GameBuyRequest) (*pb.GameMoveResponse, error) {
	var move gameMove
	if h.l1 != nil {
		if err := h.proxy.Client.Call(ctx, "game_sign_buy", []any{req.Keys, req.MaxPriceSats}, &move); err != nil {
			return nil, err
		}
		if err := h.post(ctx, &move, req.FeeSats); err != nil {
			return nil, err
		}
		return move.proto(), nil
	}
	params := []any{req.Keys, req.MaxPriceSats, req.FeeSats}
	if err := h.proxy.Client.Call(ctx, "game_buy", params, &move); err != nil {
		return nil, err
	}
	return move.proto(), nil
}

func (h *Handler) GameCashout(ctx context.Context, req *pb.GameCashoutRequest) (*pb.GameMoveResponse, error) {
	var dest *string
	if req.Dest != "" {
		dest = &req.Dest
	}
	var move gameMove
	if h.l1 != nil {
		if err := h.proxy.Client.Call(ctx, "game_sign_cashout", []any{req.AmountSats, dest}, &move); err != nil {
			return nil, err
		}
		if err := h.post(ctx, &move, req.FeeSats); err != nil {
			return nil, err
		}
		return move.proto(), nil
	}
	params := []any{req.AmountSats, dest, req.FeeSats}
	if err := h.proxy.Client.Call(ctx, "game_cashout", params, &move); err != nil {
		return nil, err
	}
	return move.proto(), nil
}

func (h *Handler) GameDeposit(ctx context.Context, req *pb.GameDepositRequest) (*pb.GameDepositResponse, error) {
	if h.l1 != nil {
		var account struct {
			Address string `json:"address"`
		}
		if err := h.proxy.Client.Call(ctx, "game_my_account", nil, &account); err != nil {
			return nil, err
		}
		if account.Address == "" {
			return nil, fmt.Errorf("the sidepot node has no game account yet")
		}
		txid, err := h.l1.Deposit(ctx, Slot, account.Address, int64(req.ValueSats), int64(req.FeeSats))
		if err != nil {
			return nil, err
		}
		return &pb.GameDepositResponse{Txid: txid}, nil
	}
	var txid string
	params := []any{req.ValueSats, req.FeeSats}
	if err := h.proxy.Client.Call(ctx, "game_deposit", params, &txid); err != nil {
		return nil, err
	}
	return &pb.GameDepositResponse{Txid: txid}, nil
}

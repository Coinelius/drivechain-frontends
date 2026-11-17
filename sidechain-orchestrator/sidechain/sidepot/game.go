package sidepot

import (
	"context"

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
	Txid    string `json:"txid"`
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

func (h *Handler) GameBuy(ctx context.Context, req *pb.GameBuyRequest) (*pb.GameMoveResponse, error) {
	var move gameMove
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
	params := []any{req.AmountSats, dest, req.FeeSats}
	if err := h.proxy.Client.Call(ctx, "game_cashout", params, &move); err != nil {
		return nil, err
	}
	return move.proto(), nil
}

func (h *Handler) GameDeposit(ctx context.Context, req *pb.GameDepositRequest) (*pb.GameDepositResponse, error) {
	var txid string
	params := []any{req.ValueSats, req.FeeSats}
	if err := h.proxy.Client.Call(ctx, "game_deposit", params, &txid); err != nil {
		return nil, err
	}
	return &pb.GameDepositResponse{Txid: txid}, nil
}

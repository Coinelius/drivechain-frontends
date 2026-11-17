package sidepot

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	pb "github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/gen/sidepot/v1"
	"github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/sidechain"
)

// fakeNode answers each JSON-RPC method with a fixed result and records the
// params it was sent.
func fakeNode(t *testing.T, results map[string]string) (*sidechain.JSONRPCProxy, map[string]string) {
	t.Helper()
	got := map[string]string{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			Method string          `json:"method"`
			Params json.RawMessage `json:"params"`
			ID     json.RawMessage `json:"id"`
		}
		require.NoError(t, json.Unmarshal(body, &req))
		got[req.Method] = string(req.Params)
		result, ok := results[req.Method]
		if !ok {
			result = "null"
		}
		_, _ = w.Write([]byte(`{"jsonrpc":"2.0","id":` + string(req.ID) + `,"result":` + result + `}`))
	}))
	t.Cleanup(srv.Close)
	host, portText, err := net.SplitHostPort(srv.Listener.Addr().String())
	require.NoError(t, err)
	port, err := strconv.Atoi(portText)
	require.NoError(t, err)
	return sidechain.NewJSONRPCProxy(host, port), got
}

func TestGameStateReadsBothViews(t *testing.T) {
	proxy, _ := fakeNode(t, map[string]string{
		"game_state": `{"accounts":2,"bonus_pool_sats":19,"clock":10,"deadline":20,"l1_height":100,"pot_sats":500,
			"price_sats":1000000,"round":3,"start_height":90,"streak":null,
			"preview":{"accounts":3,"bonus_pool_sats":25,"clock":12,"deadline":26,"l1_height":102,"pot_sats":900,
			"price_sats":1010000,"round":3,"streak":null}}`,
	})
	resp, err := NewHandler(proxy).GetGameState(context.Background(), &pb.GetGameStateRequest{})
	require.NoError(t, err)
	assert.Equal(t, uint32(90), resp.StartHeight)
	assert.Equal(t, uint32(100), resp.Confirmed.L1Height)
	assert.Equal(t, uint64(500), resp.Confirmed.PotSats)
	assert.Equal(t, uint32(102), resp.Preview.L1Height)
	assert.Equal(t, uint32(26), resp.Preview.Deadline)
	assert.Equal(t, uint64(1010000), resp.Preview.PriceSats)
	assert.Equal(t, uint32(3), resp.Preview.Accounts)
}

func TestGameStateOfANodeWithNoGame(t *testing.T) {
	proxy, _ := fakeNode(t, map[string]string{"game_state": "null"})
	resp, err := NewHandler(proxy).GetGameState(context.Background(), &pb.GetGameStateRequest{})
	require.NoError(t, err)
	assert.Nil(t, resp.Confirmed)
	assert.Nil(t, resp.Preview)
}

func TestGameAccountReadsBothViews(t *testing.T) {
	proxy, _ := fakeNode(t, map[string]string{
		"game_my_account": `{"balance_sats":50,"keys":1,"nonce":2,"key":"ab","address":"spot:ab",
			"preview":{"balance_sats":40,"keys":3,"nonce":4}}`,
	})
	resp, err := NewHandler(proxy).GetGameAccount(context.Background(), &pb.GetGameAccountRequest{})
	require.NoError(t, err)
	assert.Equal(t, "spot:ab", resp.Address)
	assert.Equal(t, uint64(50), resp.Confirmed.BalanceSats)
	assert.Equal(t, uint64(3), resp.Preview.Keys)
	assert.Equal(t, uint64(4), resp.Preview.Nonce)
}

func TestGameMovesSendTheNodeItsParams(t *testing.T) {
	move := `{"txid":"aa","round":3,"nonce":5,"expires":15}`
	proxy, got := fakeNode(t, map[string]string{
		"game_buy": move, "game_cashout": move, "game_deposit": `"bb"`,
	})
	h := NewHandler(proxy)
	ctx := context.Background()

	buy, err := h.GameBuy(ctx, &pb.GameBuyRequest{Keys: 7})
	require.NoError(t, err)
	assert.Equal(t, "aa", buy.Txid)
	assert.Equal(t, uint32(15), buy.Expires)
	assert.JSONEq(t, `[7,null,null]`, got["game_buy"])

	limit := uint64(1030301)
	_, err = h.GameBuy(ctx, &pb.GameBuyRequest{Keys: 1, MaxPriceSats: &limit})
	require.NoError(t, err)
	assert.JSONEq(t, `[1,1030301,null]`, got["game_buy"])

	_, err = h.GameCashout(ctx, &pb.GameCashoutRequest{AmountSats: 0})
	require.NoError(t, err)
	assert.JSONEq(t, `[0,null,null]`, got["game_cashout"])

	_, err = h.GameCashout(ctx, &pb.GameCashoutRequest{AmountSats: 900, Dest: "addr"})
	require.NoError(t, err)
	assert.JSONEq(t, `[900,"addr",null]`, got["game_cashout"])

	deposit, err := h.GameDeposit(ctx, &pb.GameDepositRequest{ValueSats: 5000, FeeSats: 1000})
	require.NoError(t, err)
	assert.Equal(t, "bb", deposit.Txid)
	assert.JSONEq(t, `[5000,1000]`, got["game_deposit"])
}

type bootHost struct {
	backendOnly bool
	rpcErr      error
	cookie      string
	esplora     string
}

func (h bootHost) BackendOnly() bool { return h.backendOnly }
func (h bootHost) MainchainRPC() (string, int, error) {
	return "127.0.0.1", 8332, h.rpcErr
}
func (h bootHost) MainchainReader(context.Context) (string, error) { return "", nil }
func (h bootHost) MainchainCookie() string                         { return h.cookie }
func (h bootHost) MainchainEsplora() string                        { return h.esplora }

func TestNodeBootsWithTheMainchainRPC(t *testing.T) {
	node := NewNode(sidechain.NewJSONRPCProxy("127.0.0.1", 1))

	args, err := node.Args(context.Background(), bootHost{backendOnly: true, cookie: "/data/.cookie"})
	require.NoError(t, err)
	assert.Equal(t, []string{"--headless", "--l1-rpc-url=http://127.0.0.1:8332", "--l1-rpc-cookie=/data/.cookie"}, args)

	args, err = node.Args(context.Background(), bootHost{})
	require.NoError(t, err)
	assert.Equal(t, []string{"--l1-rpc-url=http://127.0.0.1:8332"}, args)

	_, err = node.Args(context.Background(), bootHost{rpcErr: errors.New("no mainchain node")})
	assert.Error(t, err, "the node cannot read the game without a mainchain node")
}

func TestNodeInLightModeReadsEsplora(t *testing.T) {
	node := NewNode(sidechain.NewJSONRPCProxy("127.0.0.1", 1))

	host := bootHost{backendOnly: true, esplora: "https://esplora.example", rpcErr: errors.New("no mainchain node")}
	args, err := node.Args(context.Background(), host)
	require.NoError(t, err, "a light install has no mainchain node to ask")
	assert.Equal(t, []string{"--headless", "--l1-esplora-url=https://esplora.example"}, args)
}

// fakeL1 records what the mainchain wallet was asked to send.
type fakeL1 struct {
	data, destination string
	fee, amount       int64
	slot              uint8
	err               error
}

func (f *fakeL1) SendData(_ context.Context, dataHex string, feeSats int64) (string, error) {
	f.data, f.fee = dataHex, feeSats
	return "l1txid", f.err
}

func (f *fakeL1) Deposit(_ context.Context, slot uint8, destination string, amountSats, feeSats int64) (string, error) {
	f.slot, f.destination, f.amount, f.fee = slot, destination, amountSats, feeSats
	return "deposittxid", f.err
}

func TestGameMovesGoOutThroughTheMainchainWallet(t *testing.T) {
	signed := `{"entry":"53504f54","round":3,"nonce":5,"expires":15}`
	proxy, got := fakeNode(t, map[string]string{
		"game_sign_buy": signed, "game_sign_cashout": signed,
		"game_my_account": `{"address":"spot:ab","key":"ab"}`,
	})
	h := NewHandler(proxy)
	l1 := &fakeL1{}
	h.SetL1Wallet(l1)
	ctx := context.Background()

	buy, err := h.GameBuy(ctx, &pb.GameBuyRequest{Keys: 7})
	require.NoError(t, err)
	assert.JSONEq(t, `[7,null]`, got["game_sign_buy"], "the node signs and does not post")
	assert.NotContains(t, got, "game_buy")
	assert.Equal(t, "l1txid", buy.Txid)
	assert.Equal(t, uint64(5), buy.Nonce)
	assert.Equal(t, "53504f54", l1.data)
	assert.Equal(t, int64(1000), l1.fee, "the default fee")

	fee := uint64(2500)
	_, err = h.GameCashout(ctx, &pb.GameCashoutRequest{AmountSats: 900, Dest: "addr", FeeSats: &fee})
	require.NoError(t, err)
	assert.JSONEq(t, `[900,"addr"]`, got["game_sign_cashout"])
	assert.Equal(t, int64(2500), l1.fee)

	deposit, err := h.GameDeposit(ctx, &pb.GameDepositRequest{ValueSats: 5000, FeeSats: 1200})
	require.NoError(t, err)
	assert.Equal(t, "deposittxid", deposit.Txid)
	assert.Equal(t, uint8(88), l1.slot)
	assert.Equal(t, "spot:ab", l1.destination, "the deposit names the game account, not a sidechain address")
	assert.Equal(t, int64(5000), l1.amount)
	assert.NotContains(t, got, "game_deposit")
}

func TestAMoveTheWalletRefusesIsAnError(t *testing.T) {
	proxy, _ := fakeNode(t, map[string]string{"game_sign_buy": `{"entry":"53","round":1,"nonce":1,"expires":4}`})
	h := NewHandler(proxy)
	h.SetL1Wallet(&fakeL1{err: errors.New("not enough coins")})
	_, err := h.GameBuy(context.Background(), &pb.GameBuyRequest{Keys: 1})
	assert.ErrorContains(t, err, "not enough coins")
}

func TestAnOldNodeThatCannotSignIsNamed(t *testing.T) {
	proxy, _ := fakeNode(t, map[string]string{"game_sign_buy": `{"round":1,"nonce":1,"expires":4}`})
	h := NewHandler(proxy)
	h.SetL1Wallet(&fakeL1{})
	_, err := h.GameBuy(context.Background(), &pb.GameBuyRequest{Keys: 1})
	assert.ErrorContains(t, err, "0.1.2")
}

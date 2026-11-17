package api

import (
	"bytes"
	"context"
	"encoding/hex"
	"strings"
	"testing"

	"github.com/btcsuite/btcd/wire"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	orchestrator "github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator"
)

func broadcastTx(t *testing.T, rawHex string) wire.MsgTx {
	t.Helper()
	raw, err := hex.DecodeString(rawHex)
	require.NoError(t, err)
	var tx wire.MsgTx
	require.NoError(t, tx.Deserialize(bytes.NewReader(raw)))
	return tx
}

// A Sidepot node reads a move only from an OP_RETURN whose data is one push,
// and a 128-byte buy takes OP_PUSHDATA1.
func TestSidepotMoveIsOneDataPush(t *testing.T) {
	h, chain, _ := depositHarness(t, 88)
	entry := "53504f540001" + strings.Repeat("ab", 122)
	require.Len(t, entry, 256, "a buy is 128 bytes")

	txid, err := NewSidepotWallet(h).SendData(context.Background(), entry, 1_000)
	require.NoError(t, err)
	require.Len(t, chain.broadcast, 1)
	tx := broadcastTx(t, chain.broadcast[0])
	assert.Equal(t, tx.TxID(), txid)

	want, err := hex.DecodeString("6a4c80" + entry)
	require.NoError(t, err)
	var carriers int
	for _, out := range tx.TxOut {
		if len(out.PkScript) > 0 && out.PkScript[0] == 0x6a {
			carriers++
			assert.Equal(t, want, out.PkScript, "OP_RETURN OP_PUSHDATA1 128 and the entry")
			assert.Zero(t, out.Value)
		}
	}
	assert.Equal(t, 1, carriers, "one data output")

	_, err = NewSidepotWallet(h).SendData(context.Background(), "not hex", 1_000)
	assert.Error(t, err)
}

func TestSidepotDepositNamesTheGameAccount(t *testing.T) {
	h, chain, _ := depositHarness(t, 88)
	account := "spot:" + strings.Repeat("7b", 32)

	txid, err := NewSidepotWallet(h).Deposit(context.Background(), 88, account, 100_000, 1_000)
	require.NoError(t, err)
	require.Len(t, chain.broadcast, 1)
	tx := broadcastTx(t, chain.broadcast[0])
	assert.Equal(t, tx.TxID(), txid)

	require.GreaterOrEqual(t, len(tx.TxOut), 2)
	assert.Equal(t, orchestrator.M8TreasuryScript(88), tx.TxOut[0].PkScript, "the request output comes first")
	assert.Equal(t, int64(100_000), tx.TxOut[0].Value)
	// 69 bytes of ASCII: OP_RETURN, a direct push of 0x45 bytes.
	assert.Equal(t, append([]byte{0x6a, 0x45}, []byte(account)...), tx.TxOut[1].PkScript,
		"the game account follows as text, as the game reads it")
}

func TestSidepotDepositRefusesWhatIsNotAGameAccount(t *testing.T) {
	h, chain, _ := depositHarness(t, 88)
	w := NewSidepotWallet(h)
	ctx := context.Background()

	for _, destination := range []string{"", "sidechainaddress", "spot:abcd", "spot:" + strings.Repeat("7B", 32), "s88_" + strings.Repeat("7b", 32)} {
		_, err := w.Deposit(ctx, 88, destination, 100_000, 1_000)
		assert.Error(t, err, destination)
	}
	_, err := w.Deposit(ctx, 88, "spot:"+strings.Repeat("7b", 32), 0, 1_000)
	assert.Error(t, err, "no amount")
	assert.Empty(t, chain.broadcast)
}

func TestSidepotDepositRefusesAnInactiveSlot(t *testing.T) {
	h, chain, _ := depositHarness(t, 9)
	_, err := NewSidepotWallet(h).Deposit(context.Background(), 88, "spot:"+strings.Repeat("7b", 32), 100_000, 1_000)
	assert.ErrorContains(t, err, "slot 88")
	assert.Empty(t, chain.broadcast)
}

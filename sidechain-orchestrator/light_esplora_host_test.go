package orchestrator

import (
	"io"
	"testing"

	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/config"
)

// A chain that reads mainchain blocks itself has no local node to ask in light
// mode, so the host names the network Esplora server instead.
func TestBootHostNamesEsploraOnlyInLightMode(t *testing.T) {
	o := New(t.TempDir(), string(config.NetworkECash), t.TempDir(), nil, zerolog.New(io.Discard))
	host := bootHost{orch: o}

	require.NoError(t, WriteNodeMode(o.BitwindowDir, NodeModeFull))
	assert.Empty(t, host.MainchainEsplora(), "a full install reads its own node")

	require.NoError(t, WriteNodeMode(o.BitwindowDir, NodeModeLight))
	esplora := host.MainchainEsplora()
	assert.Equal(t, config.EsploraURLForNetwork(config.NetworkECash), esplora)
	assert.NotEmpty(t, esplora, "eCash publishes an Esplora server")
	_, _, err := host.MainchainRPC()
	assert.Error(t, err, "and it has no mainchain node")
}

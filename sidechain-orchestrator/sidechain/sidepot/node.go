package sidepot

import (
	"context"
	"fmt"

	"github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/sidechain"
)

// Node speaks the Sidepot JSON-RPC. Its node reads game moves from mainchain
// blocks: from the local mainchain node, so it boots with that node's RPC
// address and cookie, or in light mode from the network's Esplora server.
type Node struct {
	*sidechain.JSONRPCProxy
}

func NewNode(proxy *sidechain.JSONRPCProxy) *Node {
	return &Node{JSONRPCProxy: proxy}
}

func (n *Node) Args(ctx context.Context, host sidechain.Host) ([]string, error) {
	args, err := n.JSONRPCProxy.Args(ctx, host)
	if err != nil {
		return nil, err
	}
	if esplora := host.MainchainEsplora(); esplora != "" {
		return append(args, "--l1-esplora-url="+esplora), nil
	}
	rpcHost, rpcPort, err := host.MainchainRPC()
	if err != nil {
		return nil, err
	}
	args = append(args, fmt.Sprintf("--l1-rpc-url=http://%s:%d", rpcHost, rpcPort))
	if cookie := host.MainchainCookie(); cookie != "" {
		args = append(args, "--l1-rpc-cookie="+cookie)
	}
	return args, nil
}

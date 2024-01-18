import { createConfig } from "@ponder/core";
import { http } from "viem";

import { RouterAbi } from "./abis/RouterAbi";

export default createConfig({
  networks: {
    baseSepolia: {
      chainId: 84532,
      transport: http(process.env.PONDER_RPC_URL_84532),
    },
  },
  contracts: {
    Router: {
      abi: RouterAbi,
      address: "0xa3731316e2edC593f79d09ca2AEEE6451D7BFAbA",
      network: "baseSepolia",
    },
  },
});

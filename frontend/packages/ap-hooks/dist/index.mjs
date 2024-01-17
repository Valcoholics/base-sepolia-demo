'use client'

// src/hooks/useSetup.ts
import {
  usePrepareContractWrite,
  useContractWrite,
  useWaitForTransaction
} from "wagmi";

// src/contracts/abi/routerAbi.ts
var routerAbi = [
  { inputs: [], name: "Input_Length_Mistmatch", type: "error" },
  { inputs: [], name: "Invalid_Factory", type: "error" },
  { inputs: [], name: "Invalid_Press", type: "error" },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "factories",
        type: "address[]"
      },
      {
        indexed: false,
        internalType: "bool[]",
        name: "statuses",
        type: "bool[]"
      }
    ],
    name: "FactoryRegistered",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address"
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address"
      }
    ],
    name: "OwnershipTransferred",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "press",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "pointer",
        type: "address"
      }
    ],
    name: "PressDataUpdated",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "factory",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "newPress",
        type: "address"
      }
    ],
    name: "PressRegistered",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "press",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "tokenIds",
        type: "uint256[]"
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "pointers",
        type: "address[]"
      }
    ],
    name: "TokenDataOverwritten",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "press",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "tokenIds",
        type: "uint256[]"
      }
    ],
    name: "TokenDataRemoved",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address"
      },
      {
        indexed: false,
        internalType: "address",
        name: "press",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "tokenIds",
        type: "uint256[]"
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "pointers",
        type: "address[]"
      }
    ],
    name: "TokenDataStored",
    type: "event"
  },
  {
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "factoryRegistry",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address", name: "press", type: "address" },
      { internalType: "bytes", name: "data", type: "bytes" }
    ],
    name: "overwriteTokenData",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address[]", name: "presses", type: "address[]" },
      { internalType: "bytes[]", name: "datas", type: "bytes[]" }
    ],
    name: "overwriteTokenDataMulti",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [],
    name: "owner",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "pressRegistry",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address[]", name: "factories", type: "address[]" },
      { internalType: "bool[]", name: "statuses", type: "bool[]" }
    ],
    name: "registerFactories",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address", name: "press", type: "address" },
      { internalType: "bytes", name: "data", type: "bytes" }
    ],
    name: "removeTokenData",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address[]", name: "presses", type: "address[]" },
      { internalType: "bytes[]", name: "datas", type: "bytes[]" }
    ],
    name: "removeTokenDataMulti",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address", name: "factoryImpl", type: "address" },
      { internalType: "bytes", name: "factoryInit", type: "bytes" }
    ],
    name: "setup",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address[]", name: "factoryImpls", type: "address[]" },
      { internalType: "bytes[]", name: "factoryInits", type: "bytes[]" }
    ],
    name: "setupBatch",
    outputs: [{ internalType: "address[]", name: "", type: "address[]" }],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address", name: "press", type: "address" },
      { internalType: "bytes", name: "data", type: "bytes" }
    ],
    name: "storeTokenData",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address[]", name: "presses", type: "address[]" },
      { internalType: "bytes[]", name: "datas", type: "bytes[]" }
    ],
    name: "storeTokenDataMulti",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [{ internalType: "address", name: "newOwner", type: "address" }],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address", name: "press", type: "address" },
      { internalType: "bytes", name: "data", type: "bytes" }
    ],
    name: "updatePressData",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      { internalType: "address[]", name: "presses", type: "address[]" },
      { internalType: "bytes[]", name: "datas", type: "bytes[]" }
    ],
    name: "updatePressDataMulti",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  }
];

// src/contracts/constants.ts
var router = "0xa3731316e2edC593f79d09ca2AEEE6451D7BFAbA";

// src/hooks/useSetup.ts
function useSetup({
  factory,
  factoryInit,
  prepareTxn
}) {
  const { config: setupConfig } = usePrepareContractWrite({
    address: router,
    abi: routerAbi,
    functionName: "setup",
    args: [factory, factoryInit],
    value: BigInt(0),
    enabled: prepareTxn
  });
  const { data: setupData, write: setup } = useContractWrite(setupConfig);
  const { isLoading: setupLoading, isSuccess: setupSuccess } = useWaitForTransaction({
    hash: setupData == null ? void 0 : setupData.hash
  });
  return {
    setupConfig,
    setup,
    setupLoading,
    setupSuccess
  };
}

// src/hooks/useStoreTokenData.ts
import {
  usePrepareContractWrite as usePrepareContractWrite2,
  useContractWrite as useContractWrite2,
  useWaitForTransaction as useWaitForTransaction2
} from "wagmi";
function useStoreTokenData({
  press,
  data,
  prepareTxn
}) {
  const { config: storeTokenDataConfig } = usePrepareContractWrite2({
    address: router,
    abi: routerAbi,
    functionName: "storeTokenData",
    args: [press, data],
    value: BigInt(5e14),
    enabled: prepareTxn
  });
  const { data: storeTokenDataData, write: storeTokenData } = useContractWrite2(storeTokenDataConfig);
  const { isLoading: storeTokenDataLoading, isSuccess: storeTokenDataSuccess } = useWaitForTransaction2({
    hash: storeTokenDataData == null ? void 0 : storeTokenDataData.hash
  });
  return {
    storeTokenDataConfig,
    storeTokenData,
    storeTokenDataLoading,
    storeTokenDataSuccess
  };
}

// src/hooks/useOverwriteTokenData.ts
import {
  usePrepareContractWrite as usePrepareContractWrite3,
  useContractWrite as useContractWrite3,
  useWaitForTransaction as useWaitForTransaction3
} from "wagmi";
function useOverwriteTokenData({
  press,
  data,
  prepareTxn
}) {
  const { config: overwriteTokenDataConfig } = usePrepareContractWrite3({
    address: router,
    abi: routerAbi,
    functionName: "overwriteTokenData",
    args: [press, data],
    // chainId: baseSepolia.id,
    // BigInt(0)
    value: BigInt(5e14),
    enabled: prepareTxn
  });
  const { data: overwriteTokenDataData, write: overwriteTokenData } = useContractWrite3(overwriteTokenDataConfig);
  const {
    isLoading: overwriteTokenDataLoading,
    isSuccess: overwriteTokenDataSuccess
  } = useWaitForTransaction3({
    hash: overwriteTokenDataData == null ? void 0 : overwriteTokenDataData.hash
  });
  return {
    overwriteTokenDataConfig,
    overwriteTokenData,
    overwriteTokenDataLoading,
    overwriteTokenDataSuccess
  };
}

// src/hooks/useUpdatePressData.ts
import {
  usePrepareContractWrite as usePrepareContractWrite4,
  useContractWrite as useContractWrite4,
  useWaitForTransaction as useWaitForTransaction4
} from "wagmi";
function useUpdatePressData({
  press,
  data,
  prepareTxn
}) {
  const { config: updatePressDataConfig } = usePrepareContractWrite4({
    address: router,
    abi: routerAbi,
    functionName: "updatePressData",
    args: [press, data],
    value: BigInt(5e14),
    enabled: prepareTxn
  });
  const { data: updatePressDataData, write: updatePressData } = useContractWrite4(updatePressDataConfig);
  const { isLoading: updatePressDataLoading, isSuccess: updatePressDataSuccess } = useWaitForTransaction4({
    hash: updatePressDataData == null ? void 0 : updatePressDataData.hash
  });
  return {
    updatePressDataConfig,
    updatePressData,
    updatePressDataLoading,
    updatePressDataSuccess
  };
}
export {
  useOverwriteTokenData,
  useSetup,
  useStoreTokenData,
  useUpdatePressData
};

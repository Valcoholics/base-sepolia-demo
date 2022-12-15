// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DropConfig} from "./DropConfig.sol";

import {IERC721Drop} from "zora-drops-contracts/interfaces/IERC721Drop.sol";
import {ERC721Drop} from "zora-drops-contracts/ERC721Drop.sol";

import {Publisher} from "../src/Publisher.sol";
import {IPublisher} from "../src/interfaces/IPublisher.sol";

import {AssemblyPress} from "../src/AssemblyPress.sol";
import {AssemblyPressProxy} from "../src/AssemblyPressProxy.sol";

import {IOwnableUpgradeable} from "../src/utils/IOwnableUpgradeable.sol";

contract AssemblyPressArchitectureTest is DropConfig {
    uint256 public mintPrice = 0;
    string public contractURIString1 = "test_contractURI_1/";
    string public tokenURIString1 = "test_tokenURI_1/";
    bytes public tokenURIString1_encoded = abi.encode(tokenURIString1);
    string public tokenURIString2 = "test_tokenURI_2/";
    bytes public tokenURIString2_encoded = abi.encode(tokenURIString2);

    function test_initializeProxy() public {
        // Create an instance of Assembly Press
        AssemblyPress assemblyPress = new AssemblyPress(
            address(creator),
            address(editionMetadataRenderer),
            publisher
        );
        // Create a proxy of the Assembly Press instance
        AssemblyPressProxy assemblyPressProxy = new AssemblyPressProxy(
            address(assemblyPress),
            DEFAULT_OWNER_ADDRESS
        );

        // Assert that the owner of the proxy is the supplied owner
        assertEq(IOwnableUpgradeable(address(assemblyPressProxy)).owner(), DEFAULT_OWNER_ADDRESS);
    }

    function test_createPublication() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        address zoraDrop = assemblyPress.createPublication({
            name: "TestDrop",
            symbol: "TD",
            defaultAdmin: DEFAULT_OWNER_ADDRESS,
            editionSize: 18446744073709551615,
            royaltyBPS: 1000,
            fundsRecipient: payable(DEFAULT_OWNER_ADDRESS),
            saleConfig: IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
            }),
            contractURI: contractURIString1,
            accessControl: address(onlyAdminAC),
            accessControlInit: accessControlInit,
            mintPricePerToken: mintPrice
        });
        ERC721Drop pubChannel = ERC721Drop(payable(zoraDrop));
        assertEq(onlyAdminAC.getAccessLevel(address(publisher), DEFAULT_OWNER_ADDRESS), 3);
        assertEq(pubChannel.contractURI(), contractURIString1);
    }

    function test_publish() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        address zoraDrop = assemblyPress.createPublication({
            name: "TestDrop",
            symbol: "TD",
            defaultAdmin: DEFAULT_OWNER_ADDRESS,
            editionSize: 18446744073709551615,
            royaltyBPS: 1000,
            fundsRecipient: payable(DEFAULT_OWNER_ADDRESS),
            saleConfig: IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
            }),
            contractURI: contractURIString1,
            accessControl: address(onlyAdminAC),
            accessControlInit: accessControlInit,
            mintPricePerToken: mintPrice
        });
        ERC721Drop pubChannel = ERC721Drop(payable(zoraDrop));
        IPublisher.ArtifactDetails[] memory artifacts = new IPublisher.ArtifactDetails[](1);
        artifacts[0].artifactRenderer = address(defaultMetaDecoder);
        artifacts[0].artifactMetadata = tokenURIString1_encoded;
        publisher.publish(zoraDrop, DEFAULT_OWNER_ADDRESS, artifacts);
        assertEq(pubChannel.saleDetails().totalMinted, 1);
        assertEq(pubChannel.tokenURI(1), tokenURIString1);

        // FIGURE OUT HOW TO TEST THE INDIVIDUAL VALUES FROM publisher.artifactInfo()
        // want to check if the address artifactRenderer + bytes memory artifactMetadata are correct
        // console.logBytes(tokenURIString1_encoded);
    }

    function test_edit() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        address zoraDrop = assemblyPress.createPublication({
            name: "TestDrop",
            symbol: "TD",
            defaultAdmin: DEFAULT_OWNER_ADDRESS,
            editionSize: 18446744073709551615,
            royaltyBPS: 1000,
            fundsRecipient: payable(DEFAULT_OWNER_ADDRESS),
            saleConfig: IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
            }),
            contractURI: contractURIString1,
            accessControl: address(onlyAdminAC),
            accessControlInit: accessControlInit,
            mintPricePerToken: mintPrice
        });
        ERC721Drop pubChannel = ERC721Drop(payable(zoraDrop));
        IPublisher.ArtifactDetails[] memory artifacts_1 = new IPublisher.ArtifactDetails[](1);
        artifacts_1[0].artifactRenderer = address(defaultMetaDecoder);
        artifacts_1[0].artifactMetadata = tokenURIString1_encoded;
        publisher.publish(zoraDrop, DEFAULT_OWNER_ADDRESS, artifacts_1);
        assertEq(pubChannel.saleDetails().totalMinted, 1);
        assertEq(pubChannel.tokenURI(1), tokenURIString1);

        IPublisher.ArtifactDetails[] memory artifacts_2 = new IPublisher.ArtifactDetails[](1);
        artifacts_2[0].artifactRenderer = address(defaultMetaDecoder);
        artifacts_2[0].artifactMetadata = tokenURIString2_encoded;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        publisher.edit(zoraDrop, tokenIds, artifacts_2);
    }
}

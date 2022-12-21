// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IAssemblyPress} from "./interfaces/IAssemblyPress.sol";
import {IZoraNFTCreator} from "./interfaces/IZoraNFTCreator.sol";
import {IAccessControlRegistry} from "onchain/remote-access-control/src/interfaces/IAccessControlRegistry.sol";
import {IERC721Drop} from "zora-drops-contracts/interfaces/IERC721Drop.sol";
import {ERC721Drop} from "zora-drops-contracts/ERC721Drop.sol";
import {OwnableUpgradeable} from "./utils/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ZoraNFTCreatorProxy} from "zora-drops-contracts/ZoraNFTCreatorProxy.sol";
import {Publisher} from "./Publisher.sol";
import {PublisherStorage} from "./PublisherStorage.sol";

/**
 * @title AssemblyPress
 * @notice Facilitates deployment of custom ZORA drops with extended functionality
 * @notice not audited use at own risk
 * @author Max Bochman
 *
 */
contract AssemblyPress is
    IAssemblyPress,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    PublisherStorage
{
    // ||||||||||||||||||||||||||||||||
    // ||| STORAGE ||||||||||||||||||||
    // ||||||||||||||||||||||||||||||||

    bytes32 public immutable DEFAULT_ADMIN_ROLE = 0x00;
    address public immutable zoraNFTCreatorProxy;
    Publisher public immutable publisherImplementation;

    // ||||||||||||||||||||||||||||||||
    // ||| CONSTRUCTOR ||||||||||||||||
    // ||||||||||||||||||||||||||||||||

    constructor(address _zoraNFTCreatorProxy, Publisher _publisherImplementation) {
        if (_zoraNFTCreatorProxy == address(0) || address(_publisherImplementation) == address(0)) {
            revert CantSet_ZeroAddress();
        }
        zoraNFTCreatorProxy = _zoraNFTCreatorProxy;
        publisherImplementation = _publisherImplementation;

        emit ZoraProxyAddressInitialized(zoraNFTCreatorProxy);
        emit PublisherInitialized(address(publisherImplementation));
    }

    // ||||||||||||||||||||||||||||||||
    // ||| INITIALIZER ||||||||||||||||
    // ||||||||||||||||||||||||||||||||

    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
    }

    // ||||||||||||||||||||||||||||||||
    // ||| createPublication ||||||||||
    // ||||||||||||||||||||||||||||||||

    function createPublication(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IERC721Drop.SalesConfiguration memory saleConfig,
        string memory contractURI,
        address accessControl,
        bytes memory accessControlInit,
        uint256 mintPricePerToken
    ) public nonReentrant returns (address) {
        // encode contractURI + mintPricePerToken + accessControl + accessControl init to pass into ArtifactMachineRegistry
        bytes memory publisherInitializer = abi.encode(contractURI, mintPricePerToken, accessControl, accessControlInit);

        // deploy zora collection - defaultAdmin must be address(this) here but will be updated later
        address newDropAddress = IZoraNFTCreator(zoraNFTCreatorProxy).setupDropsContract(
            name,
            symbol,
            address(this),
            editionSize,
            royaltyBPS,
            fundsRecipient,
            saleConfig,
            publisherImplementation,
            publisherInitializer
        );

        // give publisherImplementation minter role on zora drop
        ERC721Drop(payable(newDropAddress)).grantRole(MINTER_ROLE, address(publisherImplementation));

        // grant admin role to desired admin address
        ERC721Drop(payable(newDropAddress)).grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        // revoke admin role from address(this) as it differed from desired admin address
        ERC721Drop(payable(newDropAddress)).revokeRole(DEFAULT_ADMIN_ROLE, address(this));

        return newDropAddress;
    }

    // ||||||||||||||||||||||||||||||||
    // ||| promoteToEdition |||||||||||
    // ||||||||||||||||||||||||||||||||

    // @param contractAddress drop contract from which to make a series of editions
    function promoteToEdition(
        address contractAddress,
        uint256 tokenId,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IERC721Drop.SalesConfiguration memory saleConfig
    ) public nonReentrant returns (address) {
        // check if msg.sender has publication access
        if (
            IAccessControlRegistry(dropAccessControl[sourceContractAddress]).getAccessLevel(address(this), msg.sender)
                < 1
        ) {
            revert No_PublicationAccess();
        }

        // get the tokenURI of the supplied drop
        string memory tokenURI = ERC721Drop(contractAddress.tokenURI(tokenId));

        // get the contractURI of the supplied drop
        string memory tokenURI = ERC721Drop(contractAddress.contractURI());

        // calculate the hash of the tokenURI of the supplied drop
        bytes32 memory tokenURIHash = keccak256(abi.encode(ERC721Drop(contractAddress).tokenURI(tokenId)));

        // encode the original contractAddress, tokenId, tokenURI, contractURI, and tokenURIHash to initialize the provenanceRenderer
        bytes memory provenanceRendererInit = abi.encode(contractAddress, tokenId, tokenURI, contractUri, tokenURIHash);

        // deploy zora collection that pulls info from PublisherStorage
        address promotedDrop = IZoraNFTCreator(zoraNFTCreatorProxy).setupDropsContract(
            ERC721Drop(contractAddress.name), // name
            ERC721Drop(contractAddress.symbol) + "(e)", // symbol
            defaultAdmin, // defaultAdmin
            editionSize, // editionSize
            royaltyBPS, // royaltyBPS
            fundsRecipient, // fundsRecipient
            saleConfig, // saleConfig
            provenanceRenderer, // metadataRenderer
            provenanceRendererInit // metadataInitializer
        );

        return promotedDrop;
    }

    // ||||||||||||||||||||||||||||||||
    // ||| ADMIN FUNCTIONS ||||||||||||
    // ||||||||||||||||||||||||||||||||

    /// @notice Allows only the owner to upgrade the contract
    /// @param newImplementation proposed new upgrade implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

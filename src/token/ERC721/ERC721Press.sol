// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/*


                                                             .:^!?JJJJ?7!^..                    
                                                         .^?PB#&&&&&&&&&&&#B57:                 
                                                       :JB&&&&&&&&&&&&&&&&&&&&&G7.              
                                                  .  .?#&&&&#7!77??JYYPGB&&&&&&&&#?.            
                                                ^.  :PB5?7G&#.          ..~P&&&&&&&B^           
                                              .5^  .^.  ^P&&#:    ~5YJ7:    ^#&&&&&&&7          
                                             !BY  ..  ^G&&&&#^    J&&&&#^    ?&&&&&&&&!         
..           : .           . !.             Y##~  .   G&&&&&#^    ?&&&&G.    7&&&&&&&&B.        
..           : .            ?P             J&&#^  .   G&&&&&&^    :777^.    .G&&&&&&&&&~        
~GPPP55YYJJ??? ?7!!!!~~~~~~7&G^^::::::::::^&&&&~  .   G&&&&&&^          ....P&&&&&&&&&&7  .     
 5&&&&&&&&&&&Y #&&&&&&&&&&#G&&&&&&&###&&G.Y&&&&5. .   G&&&&&&^    .??J?7~.  7&&&&&&&&&#^  .     
  P#######&&&J B&&&&&&&&&&~J&&&&&&&&&&#7  P&&&&#~     G&&&&&&^    ^#P7.     :&&&&&&&##5. .      
     ........  ...::::::^: .~^^~!!!!!!.   ?&&&&&B:    G&&&&&&^    .         .&&&&&#BBP:  .      
                                          .#&&&&&B:   Y&&&&&&~              7&&&BGGGY:  .       
                                           ~&&&&&&#!  .!B&&&&BP5?~.        :##BP55Y~. ..        
                                            !&&&&&&&P^  .~P#GY~:          ^BPYJJ7^. ...         
                                             :G&&&&&&&G7.  .            .!Y?!~:.  .::           
                                               ~G&&&&&&&#P7:.          .:..   .:^^.             
                                                 :JB&&&&&&&&BPJ!^:......::^~~~^.                
                                                    .!YG#&&&&&&&&##GPY?!~:..                    
                                                         .:^^~~^^:.


*/

import {ERC721AUpgradeable} from "erc721a-upgradeable/ERC721AUpgradeable.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";

import {IERC2981Upgradeable, IERC165Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IERC721Press} from "./interfaces/IERC721Press.sol";
import {IERC721PressLogic} from "./interfaces/IERC721PressLogic.sol";
import {IOwnableUpgradeable} from "../../utils/interfaces/IOwnableUpgradeable.sol";
import {IERC721PressRenderer} from "./interfaces/IERC721PressRenderer.sol";

import {OwnableUpgradeable} from "../../utils/utils/OwnableUpgradeable.sol";
import {Version} from "../../utils/utils/Version.sol";
import {FundsReceiver} from "../../utils/utils/FundsReceiver.sol";

import {ERC721PressStorageV1} from "./storage/ERC721PressStorageV1.sol";

/**
 * @title ERC721Press
 * @notice Extensible ERC721A implementation
 * @dev Functionality is configurable using external renderer + logic contracts
 * @author Max Bochman
 * @author Salief Lewis
 */
contract ERC721Press is
    ERC721AUpgradeable,
    UUPSUpgradeable,
    IERC2981Upgradeable,
    ReentrancyGuardUpgradeable,
    IERC721Press,
    OwnableUpgradeable,
    Version(1),
    ERC721PressStorageV1,
    FundsReceiver
{
    /// @dev Recommended max mint batch size for ERC721A
    uint256 internal immutable MAX_MINT_BATCH_SIZE = 8;

    /// @dev Gas limit to send funds
    uint256 internal immutable FUNDS_SEND_GAS_LIMIT = 210_000;

    /// @dev Max royalty basis points (BPS)
    uint16 constant MAX_ROYALTY_BPS = 50_00;

    // ||||||||||||||||||||||||||||||||
    // ||| INITIALIZER ||||||||||||||||
    // ||||||||||||||||||||||||||||||||

    ///  @notice Initializes a new, creator-owned proxy of ERC721Press.sol
    ///  @dev Optional primarySaleFeeBPS + primarySaleFeeRecipient
    ///       cannot be adjusted after initialization
    ///  @dev initializerERC721A for ERC721AUpgradeable
    //        initializer` for OpenZeppelin's OwnableUpgradeable
    ///  @param _contractName Contract name
    ///  @param _contractSymbol Contract symbol
    ///  @param _initialOwner User that owns the contract upon deployment
    ///  @param _fundsRecipient Address that receives funds from sale
    ///  @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty
    ///  @param _logic Logic contract to use (access control + pricing dynamics)
    ///  @param _logicInit Logic contract initial data
    ///  @param _renderer Renderer contract to use
    ///  @param _rendererInit Renderer initial data
    ///  @param _primarySaleFeeRecipient Funds recipient on primary sales    
    ///  @param _primarySaleFeeBPS Optional fee to set on primary sales
    function initialize(
        string memory _contractName,
        string memory _contractSymbol,
        address _initialOwner,
        address payable _fundsRecipient,
        uint16 _royaltyBPS,
        IERC721PressLogic _logic,
        bytes memory _logicInit,
        IERC721PressRenderer _renderer,
        bytes memory _rendererInit,
        address payable _primarySaleFeeRecipient,
        uint16 _primarySaleFeeBPS        
    ) public initializerERC721A initializer {
        // Setup ERC721A
        __ERC721A_init(_contractName, _contractSymbol);

        // Setup reentrancy guard
        __ReentrancyGuard_init();

        // Set ownership to original sender of contract call
        __Ownable_init(_initialOwner);

        // Check if fundsRecipient, logic, or renderer are being set to the zero address
        if (_fundsRecipient == address(0) || address(_logic) == address(0) || address(_renderer) == address(0)) {
            revert Cannot_Set_Zero_Address();
        }

        // Check if _royaltyBPS is higher than immutable MAX_ROYALTY_BPS value
        if (_royaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        // Setup config variables
        config.fundsRecipient = _fundsRecipient;
        config.royaltyBPS = _royaltyBPS;
        config.logic = _logic;
        config.renderer = _renderer;

        // Initialize logic + renderer
        _logic.initializeWithData(_logicInit);
        _renderer.initializeWithData(_rendererInit);

        // Setup optional primary sales fee, skip if primarySalefeeBPS is set to zero
        if (_primarySaleFeeBPS != 0) {
            // Cannot set primarySaleFeeRecipient to zero address if feeBPS does not equal zero
            if (_primarySaleFeeRecipient == address(0)) {
                revert Cannot_Set_Zero_Address();
            }

            // Update primarySaleFee values in config, can not be updated after
            config.primarySaleFeeRecipient = _primarySaleFeeRecipient;
            config.primarySaleFeeBPS = _primarySaleFeeBPS;
        }

        emit IERC721Press.ERC1155PressInitialized({
            sender: msg.sender,
            logic: _logic,
            renderer: _renderer,
            fundsRecipient: _fundsRecipient,
            royaltyBPS: _royaltyBPS,
            primarySaleFeeRecipient: _primarySaleFeeRecipient,
            primarySaleFeeBPS: _primarySaleFeeBPS
        });
    }

    // ||||||||||||||||||||||||||||||||
    // ||| MINTING LOGIC ||||||||||||||
    // ||||||||||||||||||||||||||||||||

    /// @notice Allows user to mint token(s) from the Press contract
    /// @dev mintQuantity is restricted to uint16 even though maxSupply = uint64
    /// @param mintQuantity number of NFTs to mint
    /// @param mintData metadata to associate with the minted token(s)
    function mintWithData(uint16 mintQuantity, bytes memory mintData)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        // Cache msg.sender address
        address sender = msg.sender;

        // Call logic contract to check if user can mint
        if (IERC721PressLogic(config.logic).canMint(address(this), mintQuantity, sender) != true) {
            revert No_Mint_Access();
        }

        // Cache msg.value
        uint256 msgValue = msg.value;

        // Call logic contract to check what mintPrice is for given quantity + user
        if (msgValue != IERC721PressLogic(config.logic).totalMintPrice(address(this), mintQuantity, sender)) {
            revert Incorrect_Msg_Value();
        }

        // Batch mint NFTs to recipient address
        _mintNFTs(sender, mintQuantity);

        // Cache tokenId of first minted token so tokenId mint range can be reconstituted using events
        uint256 firstMintedTokenId = lastMintedTokenId() - mintQuantity;

        // Initialize the token's metadata if mintData is not empty
        if (mintData.length != 0) {
            IERC721PressRenderer(config.renderer).initializeTokenMetadata(mintData);
        }

        emit IERC721Press.MintWithData({
            recipient: sender,
            quantity: mintQuantity,
            mintData: mintData,
            totalMintPrice: msgValue,
            firstMintedTokenId: firstMintedTokenId
        });

        return firstMintedTokenId;
    }

    /// @notice Function to mint NFTs
    /// @dev (Important: Does not enforce max supply limit, enforce that limit earlier)
    /// @dev This batches in size of 8 as recommended by Chiru Labs
    /// @param to address to mint NFTs to
    /// @param quantity number of NFTs to mint
    function _mintNFTs(address to, uint256 quantity) internal {
        do {
            uint256 toMint = quantity > MAX_MINT_BATCH_SIZE ? MAX_MINT_BATCH_SIZE : quantity;
            _mint({to: to, quantity: toMint});
            quantity -= toMint;
        } while (quantity > 0);
    }

    // ||||||||||||||||||||||||||||||||
    // ||| CONTRACT OWNERSHIP |||||||||
    // ||||||||||||||||||||||||||||||||

    /// @dev Set new owner for access control + frontends
    /// @param newOwner address of the new owner
    function setOwner(address newOwner) public {
        // Check if msg.sender can transfer ownership
        if (msg.sender != owner() && IERC721PressLogic(config.logic).canTransfer(address(this), msg.sender) != true) {
            revert No_Transfer_Access();
        }

        // Transfer contract ownership to new owner
        _transferOwnership(newOwner);
    }

    // ||||||||||||||||||||||||||||||||
    // ||| CONFIG ACCESS ||||||||||||||
    // ||||||||||||||||||||||||||||||||

    /// @notice Function to set config.royaltyBPS
    /// @dev Max value = 5000
    /// @param newRoyaltyBPS uint16 value of `royaltyBPS`
    function setRoyaltyBPS(uint16 newRoyaltyBPS) external nonReentrant {
        // Call logic contract to check is msg.sender can update
        if (IERC721PressLogic(config.logic).canUpdateConfig(address(this), msg.sender) != true) {
            revert No_Config_Access();
        }

        // Check if `newRoyaltyBPS` is higher than immutable `MAX_ROYALTY_BPS` value
        if (newRoyaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        // Update `royaltyBPS` in config
        config.royaltyBPS = newRoyaltyBPS;

        emit UpdatedConfig({
            sender: msg.sender,
            logic: config.logic,
            renderer: config.renderer,
            fundsRecipient: config.fundsRecipient,
            royaltyBPS: newRoyaltyBPS
        });        
    }

    /// @notice Function to set config.fundsRecipient
    /// @dev Cannot set `fundsRecipient` to the zero address
    /// @param newFundsRecipient payable address to receive funds via withdraw
    function setFundsRecipient(address payable newFundsRecipient) external nonReentrant {
        // Call logic contract to check is msg.sender can update
        if (IERC721PressLogic(config.logic).canUpdateConfig(address(this), msg.sender) != true) {
            revert No_Config_Access();
        }

        // Check if `newFundsRecipient` is the zero address
        if (newFundsRecipient == address(0)) {
            revert Cannot_Set_Zero_Address();
        }

        // Update `fundsRecipient` address in config and initialize it
        config.fundsRecipient = newFundsRecipient;

        emit UpdatedConfig({
            sender: msg.sender,
            logic: config.logic,
            renderer: config.renderer,
            fundsRecipient: newFundsRecipient,
            royaltyBPS: config.royaltyBPS
        }); 
    }

    /// @notice Function to set config.logic
    /// @dev Cannot set logic to the zero address
    /// @param newLogic logic address to handle general contract logic
    /// @param newLogicInit data to initialize logic
    function setLogic(IERC721PressLogic newLogic, bytes memory newLogicInit) external nonReentrant {
        // Call logic contract to check is msg.sender can update
        if (IERC721PressLogic(config.logic).canUpdateConfig(address(this), msg.sender) != true) {
            revert No_Config_Access();
        }

        // Check if `newLogic` is the zero address
        if (address(newLogic) == address(0)) {
            revert Cannot_Set_Zero_Address();
        }

        // Update logic contract in config and initialize it
        config.logic = newLogic;
        IERC721PressLogic(newLogic).initializeWithData(newLogicInit);

        emit UpdatedConfig({
            sender: msg.sender,
            logic: newLogic,
            renderer: config.renderer,
            fundsRecipient: config.fundsRecipient,
            royaltyBPS: config.royaltyBPS
        }); 
    }

    /// @notice Function to set config.renderer
    /// @dev Cannot set renderer to the zero address
    /// @param newRenderer renderer address to handle metadata logic
    /// @param newRendererInit data to initialize renderer
    function setRenderer(IERC721PressRenderer newRenderer, bytes memory newRendererInit) external nonReentrant {
        // Call logic contract to check is msg.sender can update
        if (IERC721PressLogic(config.logic).canUpdateConfig(address(this), msg.sender) != true) {
            revert No_Config_Access();
        }

        // Check if newRenderer is the zero address
        if (address(newRenderer) == address(0)) {
            revert Cannot_Set_Zero_Address();
        }

        // Update renderer in config
        config.renderer = newRenderer;
        IERC721PressRenderer(newRenderer).initializeWithData(newRendererInit);

        emit UpdatedConfig({
            sender: msg.sender,
            logic: config.logic,
            renderer: newRenderer,
            fundsRecipient: config.fundsRecipient,
            royaltyBPS: config.royaltyBPS
        }); 
    }

    /// @notice Function to set config.logic
    /// @dev Cannot set fundsRecipient or logic or renderer to address(0)
    /// @dev Max `newRoyaltyBPS` value = 5000
    /// @param newFundsRecipient payable address to recieve funds via withdraw
    /// @param newRoyaltyBPS uint16 value of royaltyBPS
    /// @param newLogic logic address to handle general contract logic
    /// @param newLogicInit data to initialize logic    
    /// @param newRenderer renderer address to handle metadata logic
    /// @param newRendererInit data to initialize renderer
    function setConfig(
        address payable newFundsRecipient,
        uint16 newRoyaltyBPS,
        IERC721PressLogic newLogic,
        bytes memory newLogicInit,        
        IERC721PressRenderer newRenderer,
        bytes memory newRendererInit
    ) external nonReentrant {
        // Call logic contract to check is msg.sender can update
        if (IERC721PressLogic(config.logic).canUpdateConfig(address(this), msg.sender) != true) {
            revert No_Config_Access();
        }

        (bool setSuccess) = _setConfig(
            newFundsRecipient, 
            newRoyaltyBPS, 
            newLogic, 
            newLogicInit,            
            newRenderer, 
            newRendererInit
        );

        // Check if config update was successful
        if (!setSuccess) {
            revert Set_Config_Fail();
        }

        emit UpdatedConfig({
            sender: msg.sender,
            logic: newLogic,
            renderer: newRenderer,
            fundsRecipient: newFundsRecipient,
            royaltyBPS: newRoyaltyBPS
        });
    }

    /// @notice Internal handler to set config
    function _setConfig(
        address payable newFundsRecipient,
        uint16 newRoyaltyBPS,
        IERC721PressLogic newLogic,
        bytes memory newLogicInit,        
        IERC721PressRenderer newRenderer,
        bytes memory newRendererInit
    ) internal returns (bool) {
        // Check if supplied addresses are the zero address
        if (newFundsRecipient == address(0) || address(newRenderer) == address(0) || address(newLogic) == address(0)) {
            revert Cannot_Set_Zero_Address();
        }
        // Check if newRoyaltyBPS is higher than immutable MAX_ROYALTY_BPS value
        if (newRoyaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        // Update fundsRecipient address in config
        config.fundsRecipient = newFundsRecipient;

        // Update royaltyBPS in config
        config.royaltyBPS = newRoyaltyBPS;

        // Update logic in config + initialize it
        config.logic = newLogic;
        IERC721PressLogic(newLogic).initializeWithData(newLogicInit);

        // Update renderer in config + initialize it
        config.renderer = newRenderer;
        IERC721PressRenderer(newRenderer).initializeWithData(newRendererInit);

        return true;
    }

    // ||||||||||||||||||||||||||||||||
    // ||| PAYOUTS + ROYALTIES ||||||||
    // ||||||||||||||||||||||||||||||||

    /// @notice This withdraws ETH from the contract to the contract owner.
    function withdraw() external nonReentrant {
        // cache msg.sender
        address sender = msg.sender;

        // Check if withdraw is allowed for sender
        if (sender != owner() && IERC721PressLogic(config.logic).canWithdraw(address(this), sender) != true) {
            revert No_Withdraw_Access();
        }

        // Calculate primary sale fee amount
        uint256 funds = address(this).balance;
        uint256 fee = funds * config.primarySaleFeeBPS / 10_000;

        // Payout primary sale fees
        if (fee > 0) {
            (bool successFee,) = config.primarySaleFeeRecipient.call{value: fee, gas: FUNDS_SEND_GAS_LIMIT}("");
            if (!successFee) {
                revert Withdraw_FundsSendFailure();
            }
            funds -= fee;
        }

        // Payout recipient
        (bool successFunds,) = config.fundsRecipient.call{value: funds, gas: FUNDS_SEND_GAS_LIMIT}("");
        if (!successFunds) {
            revert Withdraw_FundsSendFailure();
        }

        emit FundsWithdrawn(msg.sender, config.fundsRecipient, funds, config.primarySaleFeeRecipient, fee);
    }

    // ||||||||||||||||||||||||||||||||
    // ||| VIEW CALLS |||||||||||||||||
    // ||||||||||||||||||||||||||||||||

    /// @notice Simple override for owner interface
    function owner() public view override(OwnableUpgradeable, IERC721Press) returns (address) {
        return super.owner();
    }

    /// @notice Contract uri getter
    /// @dev Call proxies to renderer
    function contractURI() external view returns (string memory) {
        return IERC721PressRenderer(config.renderer).contractURI();
    }

    /// @notice Token uri getter
    /// @dev Call proxies to renderer
    /// @param tokenId id of token to get the uri for
    function tokenURI(uint256 tokenId) public view override(ERC721AUpgradeable, IERC721Press) returns (string memory) {
        /// Reverts if the supplied token does not exist
        if (!_exists(tokenId)) {
            revert IERC721AUpgradeable.URIQueryForNonexistentToken();
        }

        return IERC721PressRenderer(config.renderer).tokenURI(tokenId);
    }

    /// @notice Getter for fundsRecipent address stored in config
    /// @dev May return 0 or revert if incorrect external logic has been configured
    /// @dev Can use maxSupplyFallback instead in the above scenario
    function maxSupply() external view returns (uint64) {
        return IERC721PressLogic(config.logic).maxSupply();
    }

    /// @notice Getter for fundsRecipent address stored in config
    function getFundsRecipient() external view returns (address payable) {
        return config.fundsRecipient;
    }

    /// @notice Getter for logic contract stored in config
    function getRoyaltyBPS() external view returns (uint16) {
        return config.royaltyBPS;
    }

    /// @notice Getter for renderer contract stored in config
    function getRenderer() external view returns (IERC721PressRenderer) {
        return IERC721PressRenderer(config.renderer);
    }

    /// @notice Getter for logic contract stored in config
    function getLogic() external view returns (IERC721PressLogic) {
        return IERC721PressLogic(config.logic);
    }

    /// @notice Getter for `feeRecipient` address stored in `primarySaleFeeDetails`
    function getPrimarySaleFeeRecipient() external view returns (address payable) {
        return config.primarySaleFeeRecipient;
    }

    /// @notice Getter for `feeBPS` stored in `primarySaleFeeDetails`
    function getPrimarySaleFeeBPS() external view returns (uint16) {
        return config.primarySaleFeeBPS;
    }

    /// @notice Config details
    /// @return IERC721Press.Configuration details
    function getConfigDetails() external view returns (IERC721Press.Configuration memory) {
        return IERC721Press.Configuration({
            fundsRecipient: config.fundsRecipient,
            royaltyBPS: config.royaltyBPS,
            logic: config.logic,
            renderer: config.renderer,
            primarySaleFeeRecipient: config.primarySaleFeeRecipient,
            primarySaleFeeBPS: config.primarySaleFeeBPS
        });
    }

    /// @dev Get royalty information for token
    /// @param _salePrice sale price for the token
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override(IERC2981Upgradeable, IERC721Press)
        returns (address receiver, uint256 royaltyAmount)
    {
        if (config.fundsRecipient == address(0)) {
            return (config.fundsRecipient, 0);
        }
        return (config.fundsRecipient, (_salePrice * config.royaltyBPS) / 10_000);
    }

    /// @notice ERC165 supports interface
    /// @param interfaceId interface id to check if supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165Upgradeable, ERC721AUpgradeable, IERC721Press)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || type(IOwnableUpgradeable).interfaceId == interfaceId
            || type(IERC2981Upgradeable).interfaceId == interfaceId || type(IERC721Press).interfaceId == interfaceId;
    }

    // ||||||||||||||||||||||||||||||||
    // ||| ERC721A CUSTOMIZATION ||||||
    // ||||||||||||||||||||||||||||||||

    /// @notice User burn function for tokenId
    /// @param tokenId token id to burn
    function burn(uint256 tokenId) public {
        // Check if burn is allowed for sender
        if (IERC721PressLogic(config.logic).canBurn(address(this), tokenId, msg.sender) != true) {
            revert No_Burn_Access();
        }

        _burn(tokenId, true);
    }

    /// @notice Start token ID for minting (1-100 vs 0-99)
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Getter for last minted token id (gets next token id and subtracts 1)
    /// @dev Also works as a "totalMinted" lookup
    function lastMintedTokenId() public view returns (uint256) {
        return _nextTokenId() - 1;
    }

    /// @notice Getter that returns number of tokens minted for a given address
    function numberMinted(address ownerAddress) external view returns (uint256) {
        return _numberMinted(ownerAddress);
    }    

    // ||||||||||||||||||||||||||||||||
    // ||| UPGRADES |||||||||||||||||||
    // ||||||||||||||||||||||||||||||||

    /// @dev Can only be called by an admin or the contract owner
    /// @param newImplementation proposed new upgrade implementation
    function _authorizeUpgrade(address newImplementation) internal override canUpgrade {}

    modifier canUpgrade() {
        // call logic contract to check is msg.sender can upgrade
        if (IERC721PressLogic(config.logic).canUpgrade(address(this), msg.sender) != true && owner() != msg.sender) {
            revert No_Upgrade_Access();
        }

        _;
    }
}

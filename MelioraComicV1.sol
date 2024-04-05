    // To integrate:
// 1. ownerOnly and/or internal (for security)
// 2. Royalties, max supply and mint price
// 3. Ability to change the above
// 4. Ability to change URI

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MelioraComicV1 is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint16;
    using SafeMath for uint8;
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenID;
    string public collectionInfoURI; // Assigns the JSON containing the collection's metadata, including ".json"
    string public defaultTokenURI; // JSON containing the metadata for non-unique tokens, including ".json"
    string public uniqueTokenBaseURI; // JSON containing the metadata folder for non-unique tokens. Does NOT INCLUDE ".json"

    // Max Supply
    uint256 public _maxSupply;

    // Whitelist
    uint16 public whitelist_minimum_requirement;
    mapping(uint16 => uint256) public mint_prices;
    mapping(uint16 => uint16) public mint_limits;
    mapping(address => uint256) public mint_counts;
    mapping(address => uint16) public whitelist_tiers;
    event WhitelistAssigned(uint16 whitelist_tier, address user_address);

    // Fund Recipients
    Counters.Counter private fundRecipientCount;
    uint16 public total_fund_weight;
    mapping(uint256 => address payable) public fund_recipient_addresses;
    mapping(address => uint16) public fund_recipient_weights;
    
    // Unique Tokens
    uint256 public unique_token_maxSupply;
    
    
    constructor() ERC721("TheGenesisOfMeliora", "MELIORA1") {
        collectionInfoURI = "https://nftstorage.link/ipfs/bafybeifpq52p2xfppv2bmfutnjr5wlfky6lex646uiyzggbtbmoj73ka7m/OathToMeliorism.json";
        defaultTokenURI = "https://nftstorage.link/ipfs/bafybeiegcseak5zngerytyaibhmm2n66uq3d7diorustrxonxrxg2xktqi/limited_edition.json";
        uniqueTokenBaseURI = "https://nftstorage.link/ipfs/bafybeiafskgsuopht5szg7tiqhzvvzl6gxblacgq32hni5jof27wgttofi/";
    }

//__________________________________________________________________________________
// Admin Functions - all admin functions begin with two underscores __

    function __mintFree(string memory token_URI) onlyOwner public returns (uint256 token_ID) {
        token_ID = ____mint(token_URI);

        return token_ID;
    }


    function __setWhitelistTier(uint16 new_whitelist_tier, address user_address) onlyOwner public returns (uint16 old_whitelist_tier) {
        old_whitelist_tier = getWhitelistTier(user_address);
        whitelist_tiers[user_address] = new_whitelist_tier;

        return(old_whitelist_tier);

        emit WhitelistAssigned(new_whitelist_tier, user_address);
    }


    function __setWhitelistMinimumRequirement(uint16 new_whitelist_minimum_requirement) onlyOwner public returns (uint16 old_whitelist_minimum_requirement) {
        old_whitelist_minimum_requirement = getWhitelistMinimumRequirement();
        whitelist_minimum_requirement = new_whitelist_minimum_requirement;

        return(old_whitelist_minimum_requirement);
    }


    function __setMintPrice(uint16 whitelist_tier, uint256 new_price) onlyOwner public returns (uint256 old_price) {
        old_price = getMintPrice(whitelist_tier);
        mint_prices[whitelist_tier] = new_price;

        return(old_price);
    }


    function __setMintLimit(uint16 whitelist_tier, uint16 new_limit) onlyOwner public returns (uint16 old_limit) {
        old_limit = getMintLimit(whitelist_tier);
        mint_limits[whitelist_tier] = new_limit;

        return(old_limit);
    }


    function __setMaxSupply(uint256 new_max_supply) onlyOwner public returns (uint256 old_max_supply) {
        old_max_supply = getMaxSupply();
        _maxSupply = new_max_supply;

        return(old_max_supply);
    }


    function __setUniqueTokenMaxSupply(uint256 new_unique_token_maxSupply) onlyOwner public returns (uint256 old_unique_token_maxSupply) {
        old_unique_token_maxSupply = getUniqueTokenSupply();
        unique_token_maxSupply = new_unique_token_maxSupply;

        return(old_unique_token_maxSupply);
    }


    function __setTokenURI(uint256 token_ID, string memory token_URI) onlyOwner public returns (string memory old_token_URI) {
        require(_exists(token_ID), "ERROR: Token does not exist");

        old_token_URI = tokenURI(token_ID);
        _setTokenURI(token_ID, token_URI);

        return(old_token_URI);
    }


    function __setDefaultTokenURI(string memory token_URI) onlyOwner public returns (string memory old_default_token_URI) {
        old_default_token_URI = getDefaultTokenURI();
        defaultTokenURI = token_URI;

        return(old_default_token_URI);
    }


    function __setUniqueTokenBaseURI(string memory token_URI) onlyOwner public returns (string memory old_unique_token_base_URI) {
        old_unique_token_base_URI = getUniqueTokenBaseURI();
        uniqueTokenBaseURI = token_URI;

        return(old_unique_token_base_URI);
    }


    function __updateAllDefaultTokenURIs() onlyOwner public returns (uint256 current_supply) {
        current_supply = getCurrentSupply();
        for (uint256 i = unique_token_maxSupply + 1; i <= current_supply; i++) {
            __setTokenURI(i, defaultTokenURI);
        }
        return(current_supply);
    }


    function __updateAllUniqueTokenURIs() onlyOwner public returns (uint256 current_supply) {
        current_supply = getCurrentSupply();
        for (uint256 i = 1; i <= Math.min(current_supply, unique_token_maxSupply); i++) {
            string memory i_string = Strings.toString(i);
            __setTokenURI(i, string(abi.encodePacked(uniqueTokenBaseURI, i_string, ".json")));
        }
        return(current_supply);
    }


    function __setFundRecipientWeight(address payable recipient_address, uint16 fund_weight) onlyOwner public returns (uint16 old_fund_weight) {
        old_fund_weight = getFundRecipientWeight(recipient_address);
        if (old_fund_weight == 0) {
            fundRecipientCount.increment();
            fund_recipient_addresses[fundRecipientCount.current()] = recipient_address;
        } else {
            total_fund_weight -= old_fund_weight;
        }

        total_fund_weight += fund_weight;
        fund_recipient_weights[recipient_address] = fund_weight;

        return(old_fund_weight);
    }


    // Sets the URI for the collection info JSON.
    function __setContractURI(string memory new_collectionInfoURI) onlyOwner public returns (string memory old_collectionInfoURI) {
        old_collectionInfoURI = collectionInfoURI;
        collectionInfoURI = new_collectionInfoURI;

        return(old_collectionInfoURI);
    }


/*
__________________________________________________________________________________
Internal Functions - all internal functions begin with 4 underscores ____
__________________________________________________________________________________
*/ 

    function ____mint(string memory token_URI) internal returns (uint256 token_ID) {
        if (_maxSupply > 0) {
            require(currentTokenID.current() < _maxSupply, "ERROR: Maximum token supply reached");
        }
        currentTokenID.increment();
        token_ID = currentTokenID.current();
        _safeMint(msg.sender, token_ID);
        _setTokenURI(token_ID, token_URI);

        mint_counts[msg.sender] = mint_counts[msg.sender] + 1;

        return token_ID;
    }


/*
__________________________________________________________________________________
Public Functions
__________________________________________________________________________________
*/ 

    function mint() public payable returns (uint256 token_ID) {
        uint16 whitelist_tier = getWhitelistTier(msg.sender);
        if (whitelist_minimum_requirement > 0){
            require(whitelist_tier >= whitelist_minimum_requirement, "ERROR: Minter's Whitelist Tier is not high enough");
        }

        uint16 mint_limit = getMintLimit(whitelist_tier);
        if (mint_limit > 0) {
            require(mint_counts[msg.sender] < mint_limit, "ERROR: Minter's mint limit has been reached");
        }
        
        uint256 mint_price = getMintPrice(whitelist_tier);
        if (mint_price > 0) {
            require(msg.value >= mint_price, "ERROR: Less funds were sent than the mint price");
        }

        string memory token_URI;

        // Unique Mint vs. Default Mint
        if (currentTokenID.current() < unique_token_maxSupply) {
            string memory token_ID_string = Strings.toString(currentTokenID.current() + 1);
            token_URI = string(abi.encodePacked(uniqueTokenBaseURI, token_ID_string, ".json"));
        } else {
            token_URI = defaultTokenURI;
        }

        // Distribute ETH to fund recipients
        if (total_fund_weight > 0) {
            for (uint256 i = 1; i <= fundRecipientCount.current(); i++) {
                if (fund_recipient_weights[fund_recipient_addresses[i]] > 0) {
                    address payable recipient_address = fund_recipient_addresses[i];
                    uint256 weighted_fund_distribution = (msg.value * fund_recipient_weights[recipient_address]) / total_fund_weight;
                    recipient_address.transfer(weighted_fund_distribution);
                }
            }
        }

        token_ID = ____mint(token_URI);

        return token_ID;
    }


    function mintBatch(uint256 amount) public payable returns (uint256 token_ID) {
        uint16 whitelist_tier = getWhitelistTier(msg.sender);
        if (whitelist_minimum_requirement > 0){
            require(whitelist_tier >= whitelist_minimum_requirement, "ERROR: Minter's Whitelist Tier is not high enough");
        }

        uint16 mint_limit = getMintLimit(whitelist_tier);
        if (mint_limit > 0) {
            require(mint_counts[msg.sender] + amount <= mint_limit, "ERROR: Minter's mint limit has been reached");
        }
        
        uint256 mint_price = getMintPrice(whitelist_tier);
        if (mint_price > 0) {
            require(msg.value >= mint_price * amount, "ERROR: Less funds were sent than the mint price");
        }


        // Distribute ETH to fund recipients
        if (total_fund_weight > 0) {
            for (uint256 i = 1; i <= fundRecipientCount.current(); i++) {
                if (fund_recipient_weights[fund_recipient_addresses[i]] > 0) {
                    address payable recipient_address = fund_recipient_addresses[i];
                    uint256 weighted_fund_distribution = (msg.value * fund_recipient_weights[recipient_address]) / total_fund_weight;
                    recipient_address.transfer(weighted_fund_distribution);
                }
            }
        }

        string memory token_URI;
        for (uint256 i = 1; i <= amount; i++) {
            // Unique Mint vs. Default Mint
            if (currentTokenID.current() < unique_token_maxSupply) {
                string memory token_ID_string = Strings.toString(currentTokenID.current() + 1);
                token_URI = string(abi.encodePacked(uniqueTokenBaseURI, token_ID_string, ".json"));
            } else {
                token_URI = defaultTokenURI;
            }
            token_ID = ____mint(token_URI);
        }

        return token_ID;
    }


    function getWhitelistTier (address user_address) public view returns (uint16) {
        // should return 0 if not whitelisted
        return (whitelist_tiers[user_address]);
    }


    function getWhitelistMinimumRequirement () public view returns (uint16) {
        return (whitelist_minimum_requirement);
    }
    

    function getMintPrice (uint16 whitelist_tier) public view returns (uint256) {
        return (mint_prices[whitelist_tier]);
    }


    function getUserMintPrice (address user_address) public view returns (uint256) {
        return (mint_prices[getWhitelistTier(user_address)]);
    }


    function getMyMintPrice () public view returns (uint256) {
        return (mint_prices[getWhitelistTier(msg.sender)]);
    }


    function getMintLimit (uint16 whitelist_tier) public view returns (uint16) {
        return (mint_limits[whitelist_tier]);
    }


    function getUserMintLimit (address user_address) public view returns (uint16) {
        return (mint_limits[getWhitelistTier(user_address)]);
    }


    function getMyMintLimit () public view returns (uint16) {
        return (mint_limits[getWhitelistTier(msg.sender)]);
    }


    function getMaxSupply () public view returns (uint256) {
        return (_maxSupply);
    }


    function getCurrentSupply() public view returns (uint256) {
        return currentTokenID.current();
    }


    function getUniqueTokenSupply() public view returns (uint256 unique_token_supply) {
        if (unique_token_maxSupply < currentTokenID.current()) {
            unique_token_supply = unique_token_maxSupply;
        } else {
            unique_token_supply = currentTokenID.current();
        }
        return (unique_token_supply);
    }


    function getUniqueTokenMaxSupply() public view returns (uint256) {
        return unique_token_maxSupply;
    }


    function getDefaultTokenURI() public view returns (string memory) {
        return defaultTokenURI;
    }


    function getUniqueTokenBaseURI() public view returns (string memory) {
        return uniqueTokenBaseURI;
    }


    function getFundRecipientWeight (address recipient_address) public view returns (uint16) {
        return (fund_recipient_weights[recipient_address]);
    }


    function getTotalFundWeight () public view returns (uint16) {
        return (total_fund_weight);
    }


    function getFundRecipientCount () public view returns (uint256) {
        return (fundRecipientCount.current());
    }
    

/*
__________________________________________________________________________________
Platform Functions
__________________________________________________________________________________
*/ 

    // Required for OpenSea to obtain information about the entire collection, such as the profile image and description
    function contractURI() public view returns (string memory) {
        return collectionInfoURI;
    }
}
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

struct Color {
    uint256 red;
    uint256 green;
    uint256 blue;
}

struct Genes {
    Color body;
    Color hair;
    // Color public body = Color(0, 0, 0);
    // Color storage hair = Color(0, 0, 0);
    uint8 breed;
    uint8 pattern;
}
contract PonyBase {
    /*** EVENTS ***/

    /// @dev The Birth event is fired whenever a new kitten comes into existence. This obviously
    ///  includes any time a cat is created through the giveBirth method, but it is also called
    ///  when a new gen0 cat is created.
    event Birth(address owner, uint256 ponyId, uint256 matronId, uint256 sireId, Genes genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a kitten
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, uint256 tokenId);

    /*** DATA TYPES ***/

    /// @dev The main Kitty struct. Every cat in CryptoKitties is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Pony {
        // The Kitty's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A cat's genes never change.
        Genes genes;
        bool isFemale;

        // The timestamp from the block when this cat came into existence.
        uint64 birthTime;

        // The minimum timestamp after which this cat can engage in breeding
        // activities again. This same timestamp is used for the pregnancy
        // timer (for matrons) as well as the siring cooldown.
        uint64 cooldownEndBlock;

        // The ID of the parents of this kitty, set to 0 for gen0 ponies.
        // Note that using 32-bit unsigned integers limits us to a "mere"
        // 4 billion ponies. This number might seem small until you realize
        // that Ethereum currently has a limit of about 500 million
        // transactions per year! So, this definitely won't be a problem
        // for several years (even as Ethereum learns to scale).
        uint32 matronId;
        uint32 sireId;

        // Set to the ID of the sire cat for matrons that are pregnant,
        // zero otherwise. A non-zero value here is how we know a cat
        // is pregnant. Used to retrieve the genetic material for the new
        // kitten when the birth transpires.
        uint32 siringWithId;

        // Set to the index in the cooldown array (see below) that represents
        // the current cooldown duration for this Kitty. This starts at zero
        // for gen0 cats, and is initialized to floor(generation/2) for others.
        // Incremented by one for each successful breeding action, regardless
        // of whether this cat is acting as matron or sire.
        uint16 cooldownIndex;

        // The "generation number" of this cat. Cats minted by the CK contract
        // for sale are called "gen0" and have a generation number of 0. The
        // generation number of all other cats is the larger of the two generation
        // numbers of their parents, plus one.
        // (i.e. max(matron.generation, sire.generation) + 1)
        uint16 generation;
    }

    /*** CONSTANTS ***/

    /// @dev A lookup table indicating the cooldown duration after any successful
    ///  breeding action, called "pregnancy time" for matrons and "siring cooldown"
    ///  for sires. Designed such that the cooldown roughly doubles each time a cat
    ///  is bred, encouraging owners not to just keep breeding the same pony over
    ///  and over again. Caps out at one week (a pony can breed an unbounded number
    ///  of times, and the maximum cooldown is always seven days).
    uint32[14] public cooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];

    // An approximation of currently how many seconds are in between blocks.
    uint256 public secondsPerBlock = 15;

    /*** STORAGE ***/

    /// @dev An array containing the Pony struct for all Ponies in existence. The ID
    ///  of each pony is actually an index into this array. Note that ID 0 is a negacat,
    ///  the unKitty, the mythical beast that is the parent of all gen0 cats. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, cat ID 0 is invalid... ;-)
    Pony[] ponies;

    /// @dev A mapping from cat IDs to the address that owns them. All cats have
    ///  some valid owner address, even gen0 cats are created with a non-zero owner.
    mapping (uint256 => address) public ponyIndexToOwner;

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) ownershipTokenCount;

    /// @dev A mapping from PonyIDs to an address that has been approved to call
    ///  transferFrom(). Each Pony can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public ponyIndexToApproved;

    /// @dev Assigns ownership of a specific Kitty to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of kittens is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        ponyIndexToOwner[_tokenId] = _to;
        // When creating new kittens _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
        }
        // Emit the transfer event.
        emit Transfer(_from, _to, _tokenId);
    }

    
    // Randomness provided by this is predicatable. Use with care!
    function randomNumber2() internal view returns (uint) {
        return uint(blockhash(block.number - 1));
    }
    
    // returns either true or false randomly (matron int or sire int)
    function randomBool() internal view returns (bool) {
        if ((randomNumber2() % 2) == 0) {
            return true;
        }
        return false;
    }
    
    function _createPony(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        Genes memory _genes,
        address _owner
    )
        internal
        returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createKitty() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));

        // New kitty starts with the same cooldown as parent gen/2 
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }

        
        Pony memory _pony = Pony({
            genes: _genes,
            isFemale: ((ponies.length % 2) == 0), 
            birthTime: uint64(block.timestamp),
            cooldownEndBlock: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation)
        });
        ponies.push(_pony);
        uint256 newPonyId = ponies.length - 1;

        // It's probably never going to happen, 4 billion cats is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newPonyId == uint256(uint32(newPonyId)));

        // emit the birth event
        emit Birth(
            _owner,
            newPonyId,
            uint256(_pony.matronId),
            uint256(_pony.sireId),
            _pony.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(address(0), _owner, newPonyId);

        return newPonyId;
    }
}


// contract ERC721 {
//     // Required methods
//     function totalSupply() public view returns (uint256 total);
//     function balanceOf(address _owner) public view returns (uint256 balance);
//     function ownerOf(uint256 _tokenId) external view returns (address owner);
//     function approve(address _to, uint256 _tokenId) external;
//     function transfer(address _to, uint256 _tokenId) external;
//     function transferFrom(address _from, address _to, uint256 _tokenId) external;

//     // Events
//     event Transfer(address from, address to, uint256 tokenId);
//     event Approval(address owner, address approved, uint256 tokenId);

//     // Optional
//     // function name() public view returns (string name);
//     // function symbol() public view returns (string symbol);
//     // function tokensOfOwner(address _owner) external view returns (uint256[] tokenIds);
//     // function tokenMetadata(uint256 _tokenId, string _preferredTransport) public view returns (string infoUrl);

//     // ERC-165 Compatibility (https://github.com/ethereum/EIPs/issues/165)
//     function supportsInterface(bytes4 _interfaceID) external view returns (bool);
// }

/// @title The facet of the CryptoKitties core contract that manages ownership, ERC-721 (draft) compliant.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev Ref: https://github.com/ethereum/EIPs/issues/721
///  See the KittyCore contract documentation to understand how the various contract facets are arranged.
contract PonyOwnership is PonyBase {

    /// @notice Name and symbol of the non fungible token, as defined in ERC721.
    string public constant name = "CryptoKitties";
    string public constant symbol = "CK";

    // The contract that will return kitty metadata
    // ERC721Metadata public erc721Metadata;

    bytes4 constant InterfaceSignature_ERC165 =
        bytes4(keccak256('supportsInterface(bytes4)'));

    bytes4 constant InterfaceSignature_ERC721 =
        bytes4(keccak256('name()')) ^
        bytes4(keccak256('symbol()')) ^
        bytes4(keccak256('totalSupply()')) ^
        bytes4(keccak256('balanceOf(address)')) ^
        bytes4(keccak256('ownerOf(uint256)')) ^
        bytes4(keccak256('approve(address,uint256)')) ^
        bytes4(keccak256('transfer(address,uint256)')) ^
        bytes4(keccak256('transferFrom(address,address,uint256)')) ^
        bytes4(keccak256('tokensOfOwner(address)')) ^
        bytes4(keccak256('tokenMetadata(uint256,string)'));

    event Approval(address owner, address approved, uint256 tokenId);
    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    ///  Returns true for any standardized interfaces implemented by this contract. We implement
    ///  ERC-165 (obviously!) and ERC-721.
    
    // Internal utility functions: These functions all assume that their input arguments
    // are valid. We leave it to public methods to sanitize their inputs and follow
    // the required logic.

    /// @dev Checks if a given address is the current owner of a particular Kitty.
    /// @param _claimant the address we are validating against.
    /// @param _tokenId kitten id, only valid when > 0
    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return ponyIndexToOwner[_tokenId] == _claimant;
    }

    /// @dev Checks if a given address currently has transferApproval for a particular Kitty.
    /// @param _claimant the address we are confirming kitten is approved for.
    /// @param _tokenId kitten id, only valid when > 0
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return ponyIndexToApproved[_tokenId] == _claimant;
    }

    /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
    ///  approval. Setting _approved to address(0) clears all transfer approval.
    ///  NOTE: _approve() does NOT send the Approval event. This is intentional because
    ///  _approve() and transferFrom() are used together for putting Kitties on auction, and
    ///  there is no value in spamming the log with Approval events in that case.
    function _approve(uint256 _tokenId, address _approved) internal {
        ponyIndexToApproved[_tokenId] = _approved;
    }

    /// @notice Returns the number of Kitties owned by a specific address.
    /// @param _owner The owner address to check.
    /// @dev Required for ERC-721 compliance
    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
    }
    function createPromoPony(uint256 red, uint256 blue, uint256 green,  address _owner) external {
        address kittyOwner = _owner;
        // require(promoCreatedCount < PROMO_CREATION_LIMIT);
        Color memory color = Color({red:red, blue:blue, green:green});
        Genes memory _genes = Genes({body: color, hair: color, breed: 1, pattern: 1});

        // promoCreatedCount++;
        _createPony(0, 0, 0, _genes, kittyOwner);
    }

    /// @notice Transfers a Kitty to another address. If transferring to a smart
    ///  contract be VERY CAREFUL to ensure that it is aware of ERC-721 (or
    ///  CryptoKitties specifically) or your Kitty may be lost forever. Seriously.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenId The ID of the Kitty to transfer.
    /// @dev Required for ERC-721 compliance.
    function transfer(
        address _to,
        uint256 _tokenId
    )
        external
    {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any kitties (except very briefly
        // after a gen0 cat is created and before it goes on auction).
        require(_to != address(this));

        // You can only send your own cat.
        require(_owns(msg.sender, _tokenId));

        // Reassign ownership, clear pending approvals, emit Transfer event.
        _transfer(msg.sender, _to, _tokenId);
    }

    /// @notice Grant another address the right to transfer a specific Kitty via
    ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the Kitty that can be transferred if this call succeeds.
    /// @dev Required for ERC-721 compliance.
    function approve(
        address _to,
        uint256 _tokenId
    )
        external
    {
        // Only an owner can grant transfer approval.
        require(_owns(msg.sender, _tokenId));

        // Register the approval (replacing any previous approval).
        _approve(_tokenId, _to);

        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a Kitty owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the Kitty to be transfered.
    /// @param _to The address that should take ownership of the Kitty. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the Kitty to be transferred.
    /// @dev Required for ERC-721 compliance.
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        external
    {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any kitties (except very briefly
        // after a gen0 cat is created and before it goes on auction).
        require(_to != address(this));
        // Check for approval and valid ownership
        require(_approvedFor(msg.sender, _tokenId));
        require(_owns(_from, _tokenId));

        // Reassign ownership (also clears pending approvals and emits Transfer event).
        _transfer(_from, _to, _tokenId);
    }

    /// @notice Returns the total number of Kitties currently in existence.
    /// @dev Required for ERC-721 compliance.
    function totalSupply() public view returns (uint) {
        return ponies.length - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given Kitty.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _tokenId)
        external
        view
        returns (address owner)
    {
        owner = ponyIndexToOwner[_tokenId];

        require(owner != address(0));
    }
    
    function genderOf(uint256 _ponyId)
        external 
        view 
        returns (bool)
        {
            Pony memory pony = ponies[_ponyId];
            return pony.isFemale;
        }

    /// @notice Returns a list of all Kitty IDs assigned to an address.
    /// @param _owner The owner whose Kitties we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive (it walks the entire Kitty array looking for cats belonging to owner),
    ///  but it also returns a dynamic array, which is only supported for web3 calls, and
    ///  not contract-to-contract calls.
    function tokensOfOwner(address _owner) external view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalCats = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all cats have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 catId;

            for (catId = 1; catId <= totalCats; catId++) {
                if (ponyIndexToOwner[catId] == _owner) {
                    result[resultIndex] = catId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    /// @dev Adapted from toString(slice) by @arachnid (Nick Johnson <arachnid@notdot.net>)
    ///  This method is licenced under the Apache License.
    ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
   


    /// @notice Returns a URI pointing to a metadata package for this token conforming to
    ///  ERC-721 (https://github.com/ethereum/EIPs/issues/721)
    /// @param _tokenId The ID number of the Kitty whose metadata should be returned.
    // function tokenMetadata(uint256 _tokenId, string memory _preferredTransport) external view returns (string memory infoUrl) {
    //     // require(erc721Metadata != address(0));
    //     bytes32[4] memory buffer;
    //     uint256 count;
    //     (buffer, count) = erc721Metadata.getMetadata(_tokenId, _preferredTransport);

    //     return _toString(buffer, count);
    // }
}

/// @title A facet of KittyCore that manages Kitty siring, gestation, and birth.
/// @author Stephen Fay (stephenfay.xyz) 
/// @dev See the PonyCore contract documentation to understand how the various contract facets are arranged.
contract PonyBreeding is PonyOwnership {
        /// @dev The Pregnant event is fired when two cats successfully breed and the pregnancy
    ///  timer begins for the matron.
    event Pregnant(address owner, uint256 matronId, uint256 sireId, uint256 cooldownEndBlock);

    /// @notice The minimum payment required to use breedWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    // uint256 public autoBirthFee = 2 finney;

    // Keeps track of number of pregnant kitties.
    uint256 public pregnantPonies;

    /// @dev Checks that a given kitten is able to breed. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending pregnancy.
    function _isReadyToBreed(Pony memory _pon) internal view returns (bool) {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the cat has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_pon.siringWithId == 0) && (_pon.cooldownEndBlock <= uint64(block.number));
    } 

    /// @dev Set the cooldownEndTime for the given Kitty, based on its current cooldownIndex.
    ///  Also increments the cooldownIndex (unless it has hit the cap).
    /// @param _pony A reference to the Pony in storage which needs its timer started.
    function _triggerCooldown(Pony storage _pony) internal {
        // Compute an estimation of the cooldown time in blocks (based on current cooldownIndex).
        _pony.cooldownEndBlock = uint64((cooldowns[_pony.cooldownIndex]/secondsPerBlock) + block.number);

        // Increment the breeding count, clamping it at 13, which is the length of the
        // cooldowns array. We could check the array size dynamically, but hard-coding
        // this as a constant saves gas. Yay, Solidity!
        if (_pony.cooldownIndex < 13) {
            _pony.cooldownIndex += 1;
        }
    }

    /// @dev Checks to see if a given Pony is a female and is pregnant and (if so) if the gestation
    ///  period has passed.
    function _isReadyToGiveBirth(Pony memory _matron) private pure returns (bool) {
        return (_matron.siringWithId != 0) && (_matron.isFemale);
    }

    /// @notice Checks that a given kitten is able to breed (i.e. it is not pregnant or
    ///  in the middle of a siring cooldown).
    /// @param _ponyId reference the id of the kitten, any user can inquire about it
    function isReadyToBreed(uint256 _ponyId)
        public
        view
        returns (bool)
    {
        require(_ponyId > 0);
        Pony storage pon = ponies[_ponyId];
        return _isReadyToBreed(pon);
    }

    /// @dev Checks whether a kitty is currently pregnant.
    /// @param _ponyId reference the id of the kitten, any user can inquire about it
    function isPregnant(uint256 _ponyId)
        public
        view
        returns (bool)
    {
        require(_ponyId > 0);
        // A pony is pregnant if and only if this field is set
        return ponies[_ponyId].siringWithId != 0;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the Kitty struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the Kitty struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidMatingPair(
        Pony storage _matron,
        uint256 _matronId,
        Pony storage _sire,
        uint256 _sireId
    )
        private
        view
        returns(bool)
    {
        // A Pony can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }

        return (_matron.isFemale != _sire.isFemale);
    }

    /// @notice Checks to see if two cats can breed together, including checks for
    ///  ownership and siring approvals. Does NOT check that both cats are ready for
    ///  breeding (i.e. breedWith could still fail until the cooldowns are finished).
    ///  TODO: Shouldn't this check pregnancy and cooldowns?!?
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canBreedWith(uint256 _matronId, uint256 _sireId)
        external
        view
        returns(bool)
    {
        require(_matronId > 0);
        require(_sireId > 0);
        Pony storage matron = ponies[_matronId];
        Pony storage sire = ponies[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId);
    }

    /// @dev Internal utility function to initiate breeding, assumes that all breeding
    ///  requirements have been checked.
    function _breedWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the Kitties from storage.
        Pony storage sire = ponies[_sireId];
        Pony storage matron = ponies[_matronId];

        // Mark the matron as pregnant, keeping track of who the sire is.
        matron.siringWithId = uint32(_sireId);

        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        pregnantPonies++;

        // Emit the pregnancy event.
        emit Pregnant(ponyIndexToOwner[_matronId], _matronId, _sireId, matron.cooldownEndBlock);
    }

    /// @notice Breed a Kitty you own (as matron) with a sire that you own, or for which you
    ///  have previously been given Siring approval. Will either make your cat pregnant, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
    /// @param _matronId The ID of the Kitty acting as matron (will end up pregnant if successful)
    /// @param _sireId The ID of the Kitty acting as sire (will begin its siring cooldown if successful)
    function breed(uint256 _matronId, uint256 _sireId) 
        external
    {
        // do a few checks, matron is just the pony used
        // Caller must own the matron.
        require(_owns(msg.sender, _matronId));

        // Grab a reference to the potential matron
        Pony storage matron = ponies[_matronId];

        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(matron));

        // Grab a reference to the potential sire
        Pony storage sire = ponies[_sireId];

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(sire));

        // Test that these cats are a valid mating pair.
        require(_isValidMatingPair(
            matron,
            _matronId,
            sire,
            _sireId
        ));

        // All checks passed, pony gets pregnant!
        _breedWith(_matronId, _sireId);
    }

    
    // Randomness provided by this is predicatable. Use with care!
    function randomNumber() internal view returns (uint) {
        return uint(blockhash(block.number - 1));
    }
    
    // returns either m or s randomly (matron int or sire int)
    function randomChoice(uint8 m, uint8 s) internal view returns (uint8) {
        if ((randomNumber() % 2) == 0) {
            return m;
        }
        return s;
    }


    function mean(uint256 a, uint256 b) internal pure returns (uint256) {
        return uint256((a + b)/2);
    }

    // can use this instead of mean
    function randMean(uint256 a, uint256 b) internal view returns (uint256) {
        return (uint256((a + b)/2) + ((randomNumber() % 30) - 15)) % 255;
    }

    function linearInterpolation(Color memory a, Color memory b) internal pure returns (Color memory) {
        Color memory newColor = Color({red:mean(a.red , b.red),
            green:mean(a.green , b.green),
            blue:mean(a.blue , b.blue)});
        return newColor;
    }
    
    function giveBirth(uint256 _matronId)
        external
        returns(uint256)
    {
        // Grab a reference to the matron in storage.
        Pony storage matron = ponies[_matronId];
        uint256 _sireId = matron.siringWithId;

        // Check that the matron is a valid pony.
        require(matron.birthTime != 0);

        // Check that the matron is pregnant, and that its time has come!
        require(_isReadyToGiveBirth(matron));

        // Grab a reference to the sire in storage.
        uint256 sireId = matron.siringWithId;
        Pony storage sire = ponies[sireId];

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        Genes memory childGenes = Genes({
            body: linearInterpolation(matron.genes.body, sire.genes.body),
            hair: linearInterpolation(matron.genes.hair, sire.genes.hair),
            breed: randomChoice(matron.genes.breed, sire.genes.breed),
            pattern: randomChoice(matron.genes.pattern, sire.genes.pattern)
        });

        // Make the new pony!
        address owner = ponyIndexToOwner[_sireId]; // the matron is the first guy that we pass, sire must be owner
        uint256 ponyId = _createPony(_matronId, matron.siringWithId, parentGen + 1, childGenes, owner);

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        delete matron.siringWithId;

        // Every time a kitty gives birth counter is decremented.
        pregnantPonies--;

        // Send the balance fee to the person who made birth happen.
        // msg.sender.send(autoBirthFee);

        // return the new kitten's ID
        return ponyId;
    }
    
    function giveBirthForce(uint256 _matronId)
        external
        returns(uint256)
    {
        // Grab a reference to the matron in storage.
        Pony storage matron = ponies[_matronId];
        uint256 _sireId = matron.siringWithId;

        // Check that the matron is a valid pony.
        require(matron.birthTime != 0);

        // Check that the matron is pregnant, and that its time has come!
        require(_isReadyToGiveBirth(matron));

        // Grab a reference to the sire in storage.
        uint256 sireId = matron.siringWithId;
        Pony storage sire = ponies[sireId];

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        Genes memory childGenes = Genes({
            body: linearInterpolation(matron.genes.body, sire.genes.body),
            hair: linearInterpolation(matron.genes.hair, sire.genes.hair),
            breed: randomChoice(matron.genes.breed, sire.genes.breed),
            pattern: randomChoice(matron.genes.pattern, sire.genes.pattern)
        });

        // Make the new pony!
        address owner = ponyIndexToOwner[_sireId]; // the matron is the first guy that we pass, sire must be owner
        uint256 ponyId = _createPony(_matronId, matron.siringWithId, parentGen + 1, childGenes, owner);

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        delete matron.siringWithId;

        // Every time a kitty gives birth counter is decremented.
        pregnantPonies--;

        // Send the balance fee to the person who made birth happen.
        // msg.sender.send(autoBirthFee);

        // return the new kitten's ID
        return ponyId;
    }
}
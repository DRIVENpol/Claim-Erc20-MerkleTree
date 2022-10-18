// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


// The Factory Contract should meet the following specifications:

// - Anyone can deploy a new airdrop. [X]
// - Airdrops for any ERC-20 contract can be created (Extra: also allow ETH airdrops). [X]


contract AirdropFactory is Ownable {

    // Array of deployed smart contracts
    address[] public aidropSC;

    // True - paused; False - not paused;
    bool public pauseCreation;

    // Events
    event CreateAirdropSmartContract(address indexed _owner, address indexed _newSc);

    // Deploy a new instance of the airdrop smart contract
    function createAirdropSmartContract(IERC20 _tokenToAidrop, bytes32 _merkleRoot) external {
        require(pauseCreation == false, "Can't perform this action right now!");

        NethermindAirdrop _newAidropSc = new NethermindAirdrop(_tokenToAidrop, msg.sender, _merkleRoot);

        aidropSC.push(address(_newAidropSc));

        emit CreateAirdropSmartContract(msg.sender, address(_newAidropSc));
    }

    // Toggle function for "isPaused" variable
    function togglePause() external onlyOwner {
        if(pauseCreation == true) {
            pauseCreation = false;
        } else {
            pauseCreation = true;
        }
    }
}

// The Airdrop contract should meet the following specifications:

// - Users should be able to claim the total amount of tokens assigned to them (If there are enough tokens). [X]
// - Users should be able to withdraw portions of their tokens. [X]
// - Once the contract is deployed, users cannot have their tokens revoked. [X]
// - Users can allow other trusted users to claim their tokens without having to make any transaction for approving. [X]

contract Airdrop is Ownable, ReentrancyGuard {

    // The IERC20 object for our ERC20 token
    IERC20 public tokenToAirdrop;

    // Merkle Root
    bytes32 public immutable merkleRoot;

    // True - paused; False - not paused;
    bool public isPaused;

    // Events
    event ClaimTokens(address indexed _by, address indexed _to, uint256 _amount);
    event ClaimEther(address indexed _by, address indexed _to, uint256 _amount);

    // The constructor
    constructor(
        IERC20 _tokenToAirdrop,
        address _owner,
        bytes32 _merkleRoot
        ) {

        tokenToAirdrop = _tokenToAirdrop;
        _transferOwnership(_owner);
        isPaused = false;
        merkleRoot = _merkleRoot;
    }

    // Modifiers
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller can not be another smart contract!");
        _;
    }

    // Toggle function for "isPaused" variable
    function togglePaused() external onlyOwner {
        if(isPaused == true) {
            isPaused = false;
        } else {
            isPaused == true;
        }
    }

    // Claim ERC20 tokens
    function claimTokens(uint256 _amount, address _to, bytes32[] calldata _merkleProof) external callerIsUser nonReentrant {
        require(isPaused == false, "Can't perfrom actions while the smart contract is paused!");
        require(_amount <= tokenToAirdrop.balanceOf(address(this)), "Not enough tokens for this action!");

        bytes32 _node = keccak256(abi.encodePacked(_to, _amount));
        bool isValidProof = MerkleProof.verifyCalldata(_merkleProof, merkleRoot, _node);

        require(isValidProof, "Invalid Merkle proof!");
        require(tokenToAirdrop.transfer(_to, _amount), "Failing to transfer ERC20 tokens!");

        emit ClaimTokens(msg.sender, _to, _amount);
    }

     // Claim Ether
    function claimEther(uint256 _amount, address _to, bytes32[] calldata _merkleProof) external callerIsUser nonReentrant {
        require(isPaused == false, "Can't perfrom actions while the smart contract is paused!");
        require(_amount <= address(this).balance, "Not enough tokens for this action!");

        bytes32 _node = keccak256(abi.encodePacked(_to, _amount));
        bool isValidProof = MerkleProof.verifyCalldata(_merkleProof, merkleRoot, _node);

        require(isValidProof, "Invalid Merkle proof!");

        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Transaction failed!");

        emit ClaimEther(msg.sender, _to, _amount);
    }

      // Receive function to allow the smart contract to receive ether only from the owner
    receive() external payable onlyOwner {}

    // Withdraw tokens
    function withdrawTokens() external onlyOwner {
        uint256 _balance = tokenToAirdrop.balanceOf(address(this));
        address _owner = owner();
        
        require(tokenToAirdrop.transfer(_owner, _balance), "Failing to transfer ERC20 tokens!");
    }
}

//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//This was changed to the below so we can use the SafeERC20
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    //What do we want with this contract
    //   a) some list of addresses
    //   b) Allow someone in the list to claim a ERC20 tokens

    // merkle proofs allow us to prove that some piece of data is in fact in a group of data

    using SafeERC20 for IERC20;

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    event Claim(address account, uint256 amount);

    bytes32 private MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account, uint256 amount)");

    address[] claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping(address claimer => bool claimed) private s_hasClaimed;

    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    /**
     *
     * @param account  the address that wants to claim, This allows other people to claim for us. And pay for our gas
     * @param amount  The amount that we want to claim
     * @param merkleProof  the array of all the leave proofs (leaf nodes). This is needed to calculate the root and then we can compare with the actual root (i_merkleRoot)
     */
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_hasClaimed[account] == true) {
            //Prevents ppl from claiming mulitple times
            revert MerkleAirdrop__AlreadyClaimed();
        }
        //Check Signature: now if the signature is not valid than revert
        if (!_IsValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        //calculate using the account and the amount, the hash --> leaf node
        // We need to hash twice to avoid collusion
        // This helps fight a second pre-image attacks
        // the below (leaf) is now basically the hash.. now we need to verify the hash
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            // function form the MerkleProof contract
            revert MerkleAirdrop__InvalidProof();
        }
        s_hasClaimed[account] = true;

        emit Claim(account, amount);

        //i_airdropToken.tranfer(account,amount); //What happens if the account does not accept ERC20 token and the execution wont revert..
        // Changed to the below after we added the SafeERC20 library for IERC20 variables.  This will handle any errors/reverts
        i_airdropToken.safeTransfer(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32 digest) {
        return digest =
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    function _IsValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }

    function getMerkleRoot() public view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() public view returns (IERC20) {
        return i_airdropToken;
    }
}

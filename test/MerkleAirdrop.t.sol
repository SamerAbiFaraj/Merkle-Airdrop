//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;

    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public AMOUNT_TO_CLAIM = 25 * 1e18;
    uint256 public AMOUNT_TO_SEND = AMOUNT_TO_CLAIM * 4;

    address user;
    uint256 userPrivateKey;

    bytes32[] public PROOF = [
        bytes32(0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a),
        bytes32(0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576)
    ];
    address public gasPayer;

    function setUp() public {
        DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
        (airdrop, token) = deployer.run();

        // token = new BagelToken();
        // airdrop = new MerkleAirdrop(ROOT, token);

        // token.mint(token.owner(), AMOUNT_TO_SEND);
        // token.transfer(address(airdrop), AMOUNT_TO_SEND);

        (user, userPrivateKey) = makeAddrAndKey("user"); //It will make an address and private key
        gasPayer = makeAddr("gasPayer");
    }

    function testUsersCanClaim() public {
        //console.log("user address: %s", user);
        uint256 startingBalance = token.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);

        console.log("The Starting balance is: %s", startingBalance);

        //sign a message
        //vm.prank(user);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // gasPayer calls claim using the signed message
        vm.prank(gasPayer);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        uint256 endingBalance = token.balanceOf(user);

        console.log("The Ending balance is: %s", endingBalance);
        assertEq(endingBalance - startingBalance, AMOUNT_TO_CLAIM);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    VRFCoordinatorV2_5Mock vrfCoordinator;

    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");

    uint256 entranceFee;
    uint256 interval;

    function setUp() external {
        // Deploy the raffle using your script logic
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinatorAddress = config.vrfCoordinator;

        vrfCoordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);

        entranceFee = raffle.getEntranceFee();
        interval = raffle.getInterval();

        // Fund test accounts
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
    }

    function testFullRaffleFlowIntegration() public {
        console.log("Starting full integration test...");

        // 1️⃣ Players enter the raffle
        vm.startPrank(player1);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        vm.startPrank(player2);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        assertEq(address(raffle).balance, entranceFee * 2, "Raffle balance mismatch");
        assertEq(raffle.getNumberOfPlayers(), 2, "Number of players should be 2");

        // 2️⃣ Time passes - upkeep should be ready
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // 3️⃣ Perform upkeep to request random words
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RequestedRaffleWinner(uint256)")) {
                requestId = entries[i].topics[1];
                break;
            }
        }
        assertTrue(requestId != 0, "RequestId should not be zero");

        // 4️⃣ Simulate Chainlink VRF fulfilling randomness
        uint256 previousBalance = address(raffle).balance;
        vrfCoordinator.fulfillRandomWords(uint256(requestId), address(raffle));

        // 5️⃣ After fulfillment, the raffle should reset
        assertEq(raffle.getNumberOfPlayers(), 0, "Players not cleared");
        assertEq(uint256(raffle.getRaffleState()), 0, "Raffle state not reset");

        // 6️⃣ Check that winner got paid (balance decreased from contract)
        assertLt(address(raffle).balance, previousBalance, "Funds not transferred");

        console.log("Full integration flow successful!");
    }
}

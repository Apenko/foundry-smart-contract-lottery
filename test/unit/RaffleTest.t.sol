// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gaslane = config.gaslane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayerToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                           CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpKeepReturnsFalseIfHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfTimeHasPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                           PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rstate = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rstate)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if we need to get data from emitted events in our tests?
    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // Arrange
        uint256 additionalEntrants = 3; // 4 total entrants
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }

    /*//////////////////////////////////////////////////////////////
                        ADDITIONAL ADVANCED TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that the WinnerPicked event is emitted after fulfillRandomWords
    function testWinnerPickedEventEmitted() public {
        // Arrange
        address player1 = makeAddr("player1");
        address player2 = makeAddr("player2");
        address player3 = makeAddr("player3");
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);

        vm.prank(player1);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(player2);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(player3);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act - perform upkeep to trigger VRF
        raffle.performUpkeep("");

        // Assert - expect the WinnerPicked event (don’t care about who)
        vm.recordLogs();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bool found = false;
        bytes32 eventSig = keccak256("WinnerPicked(address)");
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == eventSig) {
                found = true;
                break;
            }
        }
        assertTrue(found, "WinnerPicked event not emitted");
    }

    /// @notice Test that after a round completes, raffle resets properly
    function testRaffleResetsProperlyAfterPayout() public raffleEntered skipFork {
        // Arrange: 3 players total
        for (uint256 i = 1; i < 3; i++) {
            address newPlayer = address(uint160(i + 50));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Act: fulfill random words
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert: reset checks
        assertEq(raffle.getNumberOfPlayers(), 0);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(address(raffle).balance, 0);
    }

    /// @notice Test that multiple sequential rounds work correctly
    function testMultipleSequentialRoundsWorkCorrectly() public skipFork {
        for (uint256 round = 0; round < 3; round++) {
            // Arrange
            vm.prank(PLAYER);
            raffle.enterRaffle{value: entranceFee}();
            vm.warp(block.timestamp + interval + 1);
            vm.roll(block.number + 1);

            // Perform upkeep and fulfill randomness
            vm.recordLogs();
            raffle.performUpkeep("");
            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId = entries[1].topics[1];
            VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

            // Assert
            assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
            assertEq(raffle.getNumberOfPlayers(), 0);
        }
    }

    /// @notice Test that performUpkeep reverts if called twice without new entries
    function testPerformUpkeepCannotRunTwiceInARow() public {
        // Arrange
        address player = makeAddr("player");
        vm.deal(player, 10 ether);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 2);
        vm.roll(block.number + 1);

        // Act - first call should succeed
        raffle.performUpkeep("");

        // Assert - second call should revert with full error encoding
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                address(raffle).balance,
                raffle.getNumberOfPlayers(),
                uint8(raffle.getRaffleState())
            )
        );
        raffle.performUpkeep("");
    }

    /// @notice Test that fulfillRandomWords cannot be called manually before performUpkeep
    function testFulfillRandomWordsCannotBeCalledBeforePerformUpkeep() public raffleEntered skipFork {
        uint256 invalidRequestId = 9999;
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(invalidRequestId, address(raffle));
    }

    /// @notice Test that the contract balance equals total entrance fees collected
    function testContractBalanceMatchesTotalEntries() public {
        uint256 numberOfPlayers = 5;

        for (uint256 i = 0; i < numberOfPlayers; i++) {
            address newPlayer = address(uint160(i + 100));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 expectedBalance = entranceFee * numberOfPlayers;
        assertEq(address(raffle).balance, expectedBalance);
    }

    /// @notice Test that multiple players entering emits multiple RaffleEntered events
    function testMultipleRaffleEnteredEvents() public {
        uint256 numPlayers = 3;

        for (uint256 i = 0; i < numPlayers; i++) {
            address newPlayer = address(uint160(i + 200));
            hoax(newPlayer, 1 ether);
            vm.expectEmit(true, false, false, false, address(raffle));
            emit RaffleEntered(newPlayer);
            raffle.enterRaffle{value: entranceFee}();
        }

        assertEq(raffle.getNumberOfPlayers(), numPlayers);
    }
}

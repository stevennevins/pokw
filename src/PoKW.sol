// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {toWadUnsafe, wadMul, wadDiv, wadExp} from "../lib/solmate/src/utils/SignedWadMath.sol";

contract PoKW {
    mapping(address => bool) public nodes;
    address[] public whitelistedNodes;
    uint256 public requiredWork;
    address public currentLeader;
    uint256 private nonce;
    uint256 public leadershipEndTime;
    address private owner;

    event NewLeader(address indexed leader);
    event NodeWhitelisted(address indexed node);
    event WorkSubmitted(address indexed node, uint256 work);
    event RequiredWorkUpdated(uint256 newRequiredWork);

    uint256 internal constant LEADERSHIP_DURATION = 7 days;
    uint256 internal constant TARGET_TIME = 1 hours;

    constructor(uint256 _initialRequiredWork) {
        requiredWork = _initialRequiredWork;
        owner = msg.sender;
        leadershipEndTime = block.timestamp + LEADERSHIP_DURATION;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyWhitelisted() {
        require(nodes[msg.sender], "Not whitelisted");
        _;
    }

    function whitelistNode(address _node) external onlyOwner {
        require(!nodes[_node], "Already whitelisted");
        nodes[_node] = true;
        whitelistedNodes.push(_node);
        emit NodeWhitelisted(_node);
    }

    function submitWork(uint256 _work) external onlyWhitelisted {
        require(
            block.timestamp >= leadershipEndTime,
            "Current leaders term is not over"
        );

        /// The last task after a leader's term ends should record a prevrandao value
        /// which then gets used as input here so the race doesn't begin until after
        /// the leader's term ends
        uint256 workHash = uint256(
            keccak256(abi.encodePacked(msg.sender, _work, nonce))
        );
        require(isValidWork(workHash), "Invalid work");

        emit WorkSubmitted(msg.sender, _work);

        int256 workWad = toWadUnsafe(block.timestamp - leadershipEndTime);
        electLeader();

        adjustWork(workWad);

        nonce++;
    }

    function isValidWorkPreimage(
        address node,
        uint256 work
    ) public view returns (bool) {
        uint256 workHash = uint256(
            keccak256(abi.encodePacked(node, work, nonce))
        );
        return isValidWork(workHash);
    }

    function isValidWork(uint256 workHash) internal view returns (bool) {
        return workHash < requiredWork;
    }

    function electLeader() internal {
        uint256 randomIndex = getRandomNumber() % whitelistedNodes.length;
        currentLeader = whitelistedNodes[randomIndex];
        leadershipEndTime = block.timestamp + LEADERSHIP_DURATION;
        emit NewLeader(currentLeader);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function getRandomNumber() internal view returns (uint256) {
        /// Should switch to
        /// priorityFee = min(tx.maxPriorityFeePerGas, tx.maxFeePerGas - block.baseFee)
        /// actualTotalFee = min(tx.maxFeePerGas, block.baseFee + priorityFee)
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        tx.gasprice,
                        msg.sender,
                        nonce
                    )
                )
            );
    }

    function adjustWork(int256 observedTimeWad) internal {
        int256 workWad;
        int256 targetWad = toWadUnsafe(TARGET_TIME);
        int256 requiredWorkWad = toWadUnsafe(requiredWork);
        if (observedTimeWad > targetWad) {
            // If the observed time is greater than the target time, decrease the required work
            // to make it easier to find a valid work hash. Using exponential adjustment similar to EIP-1559.
            workWad = wadMul(
                requiredWorkWad,
                wadExp(wadDiv(targetWad - observedTimeWad, targetWad))
            );
        } else {
            // If the observed time is less than the target time, increase the required work
            // to make it harder to find a valid work hash. Using exponential adjustment similar to EIP-1559.
            workWad = wadMul(
                requiredWorkWad,
                wadExp(wadDiv(observedTimeWad - targetWad, targetWad))
            );
        }
        requiredWork = uint256(workWad) / 1e18;
        emit RequiredWorkUpdated(requiredWork);
    }

    function updateRequiredWork(uint256 _newRequiredWork) external onlyOwner {
        requiredWork = _newRequiredWork;
        emit RequiredWorkUpdated(_newRequiredWork);
    }

    function getWhitelistedNodes() external view returns (address[] memory) {
        return whitelistedNodes;
    }
}

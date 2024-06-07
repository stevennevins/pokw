// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

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

        uint256 actualWorkPeriod = block.timestamp - leadershipEndTime;
        electLeader();

        adjustWork(actualWorkPeriod);

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

    function adjustWork(uint256 observedTime) internal {
        uint256 work;
        int256 observedTime = int256(observedTime);
        int256 target = int256(TARGET_TIME);
        if (observedTime > target) {
            // If the observed time is greater than the target time, decrease the required work
            // to make it easier to find a valid work hash. Using exponential adjustment similar to EIP-1559.
            work = requiredWork * exp((target - observedTime) / target);
        } else {
            // If the observed time is less than the target time, increase the required work
            // to make it harder to find a valid work hash. Using exponential adjustment similar to EIP-1559.
            work = requiredWork * exp((observedTime - target) / target);
        }
        requiredWork = work / 1e18;
        emit RequiredWorkUpdated(work);
    }

    /**
     * @dev Approximates the exponential function using a Taylor series expansion.
     * @param x The exponent to use in the calculation.
     * @return The approximate value of e^x.
     */
    function exp(int256 x) public pure returns (uint256) {
        // The number of terms to include in the Taylor series expansion
        uint256 numTerms = 10;
        uint256 factorial = 1;
        // The result of the series expansion, starting with the first term which is 1
        // Adding 18 decimals of precision to the result
        uint256 result = 1 * 1e18;
        // The power of x, starting with x^1, scaled by 1e18 for precision
        int256 powerOfX = x * int256(1e18);

        for (uint256 n = 1; n < numTerms; n++) {
            // Add the current term to the result
            result += uint256(powerOfX / int256(factorial));
            // Update powerOfX to x^(n+1), maintaining precision
            powerOfX *= x;
            // Update factorial to (n+1)!
            factorial *= (n + 1);
        }

        return result;
    }

    function updateRequiredWork(uint256 _newRequiredWork) external onlyOwner {
        requiredWork = _newRequiredWork;
        emit RequiredWorkUpdated(_newRequiredWork);
    }

    function getWhitelistedNodes() external view returns (address[] memory) {
        return whitelistedNodes;
    }
}

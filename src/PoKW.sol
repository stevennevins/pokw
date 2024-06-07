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
            "Current leader's term is not over"
        );

        uint256 workHash = uint256(
            keccak256(abi.encodePacked(msg.sender, _work, nonce))
        );
        require(isValidWork(workHash), "Invalid work");

        emit WorkSubmitted(msg.sender, _work);

        electLeader();

        nonce++;
    }

    function isValidWorkPreimage(
        address node,
        uint256 work
    ) public view returns (bool) {
        uint256 workHash = uint256(keccak256(abi.encodePacked(node, work)));
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

    function updateRequiredWork(uint256 _newRequiredWork) external onlyOwner {
        requiredWork = _newRequiredWork;
        emit RequiredWorkUpdated(_newRequiredWork);
    }

    function getWhitelistedNodes() external view returns (address[] memory) {
        return whitelistedNodes;
    }
}

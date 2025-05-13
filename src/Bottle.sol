// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interface/BottleInterface.sol";
import "./interface/ChizTokenInterface.sol";

contract Bottle is BottleInterface {
    /// @notice Admin 주소
    address public admin;
    /// @notice Bottle 아이디 카운트
    uint256 public count;
    /// @notice CHIZ 토큰 컨트랙트 주소
    ChizTokenInterface public chizToken;

    /// @notice Bottle 아이디 → BottleData 구조체
    mapping(uint256 => BottleData) public bottles;
    /// @notice Bottle 아이디 → 사용자 주소 → 모금액
    mapping(uint256 => mapping(address => uint256)) public pledgedUserToAmount;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor(address _tokenAddr) {
        admin    = msg.sender;
        chizToken = ChizTokenInterface(_tokenAddr);
    }

    function launch(
        address _target,
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external override {
        require(_startAt >= block.timestamp, "start at < now");
        require(_endAt   >= _startAt,       "end at < start at");
        require(_endAt   <= block.timestamp + 90 days, "end at > max duration");

        count += 1;
        bottles[count] = BottleData({
            creator:     msg.sender,
            target:      _target,
            title:       _title,
            description: _description,
            goal:        _goal,
            pledged:     0,
            startAt:     _startAt,
            endAt:       _endAt,
            claimed:     false
        });

        emit Launch(count, bottles[count]);
    }

    function cancel(uint256 _bottleId) external override {
        BottleData memory b = bottles[_bottleId];
        require(msg.sender == b.creator,        "not creator");
        require(block.timestamp < b.startAt,    "started");

        delete bottles[_bottleId];
        emit Cancel(_bottleId);
    }

    function pledge(uint256 _bottleId, uint256 _amount) external override {
        BottleData storage b = bottles[_bottleId];
        require(block.timestamp >= b.startAt,    "not started");
        require(!getIsEnded(_bottleId),          "campaign ended");
        require(_amount > 0,                     "amount > 0");

        b.pledged += _amount;
        pledgedUserToAmount[_bottleId][msg.sender] += _amount;
        chizToken.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_bottleId, msg.sender, _amount, b.pledged);
    }

    function unpledge(uint256 _bottleId, uint256 _amount) external override {
        BottleData storage b = bottles[_bottleId];
        require(_amount > 0,               "amount > 0");
        require(!getIsEnded(_bottleId),   "campaign ended");

        b.pledged -= _amount;
        pledgedUserToAmount[_bottleId][msg.sender] -= _amount;
        chizToken.transfer(msg.sender, _amount);

        emit Unpledge(_bottleId, msg.sender, _amount, b.pledged);
    }

    function claim(uint256 _bottleId) external override {
        require(getIsEnded(_bottleId),    "campaign not ended yet");

        BottleData storage b = bottles[_bottleId];
        require(!b.claimed,                "already claimed");

        chizToken.transfer(b.target, b.pledged);
        b.claimed = true;

        emit Claim(_bottleId, b.claimed, b.pledged);
    }

    function refund(uint256 _bottleId) external override {
        require(getIsEnded(_bottleId),   "campaign not ended yet");

        uint256 bal = pledgedUserToAmount[_bottleId][msg.sender];
        pledgedUserToAmount[_bottleId][msg.sender] = 0;
        chizToken.transfer(msg.sender, bal);

        emit Refund(_bottleId, msg.sender, bal);
    }

    function getIsEnded(uint256 _bottleId) public view override returns (bool) {
        BottleData memory b = bottles[_bottleId];
        return block.timestamp >= b.endAt || b.pledged >= b.goal;
    }

    function getBottle(uint256 _bottleId) external view override returns (BottleData memory) {
        return bottles[_bottleId];
    }

    function getBottleCreator(uint256 _bottleId) external view override returns (address) {
        return bottles[_bottleId].creator;
    }

    function getBottleGoal(uint256 _bottleId) external view override returns (uint256) {
        return bottles[_bottleId].goal;
    }

    function getBottleTotalAmount(uint256 _bottleId) external view override returns (uint256) {
        return bottles[_bottleId].pledged;
    }
}

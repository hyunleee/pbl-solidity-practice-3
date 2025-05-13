// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface BottleInterface {
    struct BottleData {
        address creator;
        address target;
        string title;
        string description;
        uint256 goal;
        uint256 pledged;
        uint32 startAt;
        uint32 endAt;
        bool claimed;
    }

    function launch(
        address _target,
        string calldata _title,
        string calldata _description,
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external;

    function cancel(uint256 _bottleId) external;
    function pledge(uint256 _bottleId, uint256 _amount) external;
    function unpledge(uint256 _bottleId, uint256 _amount) external;
    function claim(uint256 _bottleId) external;
    function refund(uint256 _bottleId) external;
    function getIsEnded(uint256 _bottleId) external view returns (bool);
    function getBottle(uint256 _bottleId) external view returns (BottleData memory);
    function getBottleCreator(uint256 _bottleId) external view returns (address);
    function getBottleGoal(uint256 _bottleId) external view returns (uint256);
    function getBottleTotalAmount(uint256 _bottleId) external view returns (uint256);

    event Launch(uint256 indexed bottleId, BottleData launchedBottle);
    event Cancel(uint256 indexed bottleId);
    event Pledge(uint256 indexed bottleId, address indexed caller, uint256 amount, uint256 totalAmount);
    event Unpledge(uint256 indexed bottleId, address indexed caller, uint256 amount, uint256 totalAmount);
    event Claim(uint256 indexed bottleId, bool claimed, uint256 amount);
    event Refund(uint256 indexed bottleId, address indexed caller, uint256 amount);
}

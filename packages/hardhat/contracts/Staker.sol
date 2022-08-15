// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  ExampleExternalContract public exampleExternalContract;

  struct User {
    uint256 balance;
    uint256 depositTimestamps;
    bool exists;
  }

  mapping(address => User) public addressToUser;
  address[] users;

  uint256 public constant rewardRatePerSecond = 0.0001 ether;
  uint256 public withdrawalTime = 120 seconds;
  uint256 public claimTime = 240 seconds;

  uint256 public initialTimestamp;

  address immutable owner;

  event Stake(address indexed sender, uint256 amount); 
  event Received(address, uint); 
  event Execute(address indexed sender, uint256 amount);

  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
      owner = 0xe8CFff263600Bb273d4CF823dBa8e3385E0a175b; // or maybe msg.sender or any other;
      initialTimestamp = block.timestamp;
  }

  receive() external payable {}
  fallback() external payable {}

  function timeLeft(uint256 deadline) public view returns (uint256) {
    if (block.timestamp >= deadline) {
      return (0);
    } else {
      return (deadline - block.timestamp);
    }
  }

  function withdrawalDeadline() public view returns (uint256) {
    return initialTimestamp + withdrawalTime;
  }

  function claimDeadline() public view returns (uint256) {
    return initialTimestamp + claimTime;
  }

  function stake() public payable isCompleted(false) {
    if (!addressToUser[msg.sender].exists) {
      users.push(msg.sender);
      addressToUser[msg.sender].exists = true;
    }

    addressToUser[msg.sender].balance += msg.value;
    addressToUser[msg.sender].depositTimestamps = block.timestamp;
    emit Stake(msg.sender, msg.value);
  }

  function withdraw() public withdrawalDeadlineReached(true) claimDeadlineReached(false) isCompleted(false) {
    require(addressToUser[msg.sender].balance > 0, "You have no balance to withdraw!");

    uint256 individualBalance = addressToUser[msg.sender].balance;
    uint256 timeBetweenBlocks = block.timestamp - addressToUser[msg.sender].depositTimestamps;
    uint256 indBalanceRewards = individualBalance + ((timeBetweenBlocks ** 2 ) * rewardRatePerSecond);

    addressToUser[msg.sender].balance = 0;

    require(address(this).balance > indBalanceRewards, "Not enough funds in the contract");
    (bool sent,) = msg.sender.call{value: indBalanceRewards}("");
    require(sent, "RIP; withdrawal failed :( ");
  }

  function execute() public claimDeadlineReached(true) isCompleted(false) {
    for (uint i; i < users.length; i++) {
      User memory user = addressToUser[users[i]];
      user.balance = 0;
      addressToUser[users[i]] = user;
    }

    uint256 contractBalance = address(this).balance;
    exampleExternalContract.complete{value: address(this).balance}();
  }

  function restart() public isCompleted(true) onlyOwner {
    exampleExternalContract.sendBackToStaker();
    initialTimestamp = block.timestamp;
  }


  modifier withdrawalDeadlineReached( bool requireReached ) {
    uint256 timeRemaining = timeLeft(withdrawalDeadline());
    if( requireReached ) {
      require(timeRemaining == 0, "Withdrawal period is not reached yet");
    } else {
      require(timeRemaining > 0, "Withdrawal period has been reached");
    }
    _;
  }

  modifier claimDeadlineReached( bool requireReached ) {
    uint256 timeRemaining = timeLeft(claimDeadline());
    if( requireReached ) {
      require(timeRemaining == 0, "Claim deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Claim deadline has been reached");
    }
    _;
  }

  modifier isCompleted(bool shouldBeCompleted) {
    bool completed = exampleExternalContract.completed();
    if (shouldBeCompleted) {
      require(completed, "Stake should be completed!");
    } else {
      require(!completed, "Stake already completed!");
    }
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Only the person, who has deployed this contract, can trigger this function");
    _;
  }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract ExampleExternalContract {

  bool public completed;
  address staker;

  function complete() public payable {
    completed = true;
  }

  // can be improved, in sense of security also
  function setStakerAddress(address _staker) public {
    staker = _staker;
  }

  // we can implement some more access logic in e.g. modifiers
  // so that such functions can not be implemented from outside
  // by unauthorized users/contracts
  function sendBackToStaker() public stakerAddressInitialized {
    (bool sent,) = payable(staker).call{value: address(this).balance}("");
    require(sent, "RIP; restart failed :( ");
    completed = false;
  }

  modifier stakerAddressInitialized() {
    require(staker != address(0), "No staker address has beed specified!");
    _;
  }
}

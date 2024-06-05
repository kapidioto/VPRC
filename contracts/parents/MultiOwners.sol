// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma abicoder v2;

import "./FeeCounter.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MultiOwners{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Owner{
        uint solution;
        bool license;
    }

    struct Vote{
        address[] voters;
        mapping(address => Status) votes;
        Status solution;
    }

    enum Status{Waiting, Allow, Reject}

    uint public ownersCount;
    uint public voteingsCount;

    mapping(address => Owner) owners;

    mapping(address => uint) gasSpended;
    
    mapping(address => uint) rewards;
    
    mapping(uint => Vote) voteingHistory;

    event OwnerStatusChanged(
        address owner,
        uint voteingNumber,
        uint ownersCount,
        bool license,
        uint _timestamp
    );
    
    event VoteingCalled(
        address initiator,
        uint voteingNumber,
        uint _timestamp
    );

    event DesidionIsMade(
        uint voteingNumber,
        address[] voters,
        uint _timestamp
    );

    event OwnerVoted(
        address owner,
        Status vote,
        uint _timestamp
    );

    event RevardDefinded(uint totalRewards);

    constructor(address[] memory inavgurated){
        ownersCount = inavgurated.length;
        for(uint i;i<ownersCount;i++){
            owners[inavgurated[i]] = Owner(0, true);
        }
        emit DesidionIsMade(0, inavgurated, block.timestamp);
    }

    modifier isOwner(){
        require(owners[msg.sender].license, "YOU AREN`T OWNER!");
        uint initialGas = gasleft();
        _;
        uint finalGas = gasleft();
        gasSpended[msg.sender] += initialGas - finalGas;
    }

    modifier isHonest(address[] memory candidats){
        require(candidats.length <= ownersCount && candidats.length >= ownersCount - 1, "THERE ARE NOT ENOUGHT OWNERS TO ACCEPT DESIDION");
        _;
    }
    modifier isVoted(uint voteingNumber){
        require(voteingNumber<=voteingsCount,"CURRENT VOTEING DOESN`T ALREDY EXIST!");
        require(voteingHistory[voteingNumber].solution != Status.Reject, "CURRENT VOTEING WAS REJECTED OR OUTDATED!");
        address[] memory array = voteingHistory[voteingNumber].voters;
        for(uint i; i<array.length; i++){
            require(voteingHistory[voteingNumber].votes[array[i]] == Status.Allow, "NOT EVERYONE VOTED!");
        }
        _;
        emit DesidionIsMade(voteingNumber, voteingHistory[voteingNumber].voters, block.timestamp);
        voteingHistory[voteingNumber].solution = Status.Reject;
    }

    function callVoteing(address[] memory congress)
    external
    isOwner()
    isHonest(congress){
        emit VoteingCalled(msg.sender, ++voteingsCount, block.timestamp);
        voteingHistory[voteingsCount].voters = congress;
        voteingHistory[voteingsCount].votes[msg.sender] = Status.Allow;
    }

    function vote(uint voteingNumber, bool newVote) 
    external
    isOwner(){
        Status myVote;
        if(newVote){
            myVote = Status.Allow;
        }else {
            myVote = Status.Reject;
        }
        require(voteingNumber<=voteingsCount,"CURRENT VOTEING DOESN`T ALREDY EXIST!");
        require(voteingHistory[voteingNumber].solution != Status.Reject, "CURRENT VOTEING WAS REJECTED OR OUTDATED!");
        require(voteingHistory[voteingNumber].votes[msg.sender] == Status.Waiting, "YOU ALREADY VOTED!");
        bool check;
        address[] memory array = voteingHistory[voteingNumber].voters;
        for(uint i; i<array.length;i++){
            if(msg.sender == array[i]){
                check = true;
                break;
            }   
        }
        require(check, "YOU AREN`T INVITED TO THIS VOTE!");

        voteingHistory[voteingNumber].votes[msg.sender] = myVote;
        if(myVote == Status.Reject){
            voteingHistory[voteingNumber].solution = Status.Reject;
        }
        emit OwnerVoted(msg.sender, myVote, block.timestamp);
    }

    function changeOvnerStatus(address inavgurated, uint voteingNumber, bool license)
    external
    isOwner()
    isVoted(voteingNumber){
        license? ownersCount++:ownersCount--;
        emit OwnerStatusChanged(inavgurated, voteingNumber, ownersCount, license, block.timestamp);
        owners[inavgurated].license = license;
        owners[inavgurated].solution = voteingNumber;
    }
    
    function checkBalance()
    external
    view
    returns(uint){
        require(owners[msg.sender].license, "YOU AREN`T OWNER!");
        return rewards[msg.sender];
    }
}
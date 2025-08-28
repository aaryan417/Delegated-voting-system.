// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Delegated Voting System
 * @dev A smart contract that enables delegated voting with transparent governance
 */
contract Project {
    
    // Struct to represent a proposal
    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    // Struct to represent a voter
    struct Voter {
        bool isRegistered;
        address delegate;
        uint256 votingPower;
        bool hasVoted;
    }
    
    // State variables
    address public owner;
    uint256 public proposalCount;
    uint256 public constant VOTING_DURATION = 7 days;
    
    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(address => address[]) public delegatedBy; // Track who delegated to whom
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event VoteDelegated(address indexed delegator, address indexed delegate);
    event VoterRegistered(address indexed voter);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting period ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        // Register owner as first voter
        voters[owner].isRegistered = true;
        voters[owner].votingPower = 1;
        emit VoterRegistered(owner);
    }
    
    /**
     * @dev Core Function 1: Register voters and manage delegation
     * @param _voter Address of the voter to register
     */
    function registerVoter(address _voter) external onlyOwner {
        require(!voters[_voter].isRegistered, "Voter already registered");
        require(_voter != address(0), "Invalid voter address");
        
        voters[_voter].isRegistered = true;
        voters[_voter].votingPower = 1;
        
        emit VoterRegistered(_voter);
    }
    
    /**
     * @dev Core Function 2: Delegate voting power to another registered voter
     * @param _delegate Address to delegate voting power to
     */
    function delegateVote(address _delegate) external onlyRegisteredVoter {
        require(voters[_delegate].isRegistered, "Delegate not registered");
        require(_delegate != msg.sender, "Cannot delegate to yourself");
        require(voters[msg.sender].delegate == address(0), "Already delegated");
        
        // Check for delegation loops
        address current = _delegate;
        while (voters[current].delegate != address(0)) {
            require(voters[current].delegate != msg.sender, "Delegation loop detected");
            current = voters[current].delegate;
        }
        
        voters[msg.sender].delegate = _delegate;
        voters[_delegate].votingPower += voters[msg.sender].votingPower;
        voters[msg.sender].votingPower = 0;
        
        // Track delegation relationship
        delegatedBy[_delegate].push(msg.sender);
        
        emit VoteDelegated(msg.sender, _delegate);
    }
    
    /**
     * @dev Core Function 3: Create proposals and cast votes
     * @param _description Description of the proposal
     */
    function createProposal(string calldata _description) external onlyRegisteredVoter {
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 proposalId = proposalCount++;
        Proposal storage newProposal = proposals[proposalId];
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + VOTING_DURATION;
        newProposal.executed = false;
        
        emit ProposalCreated(proposalId, _description, newProposal.endTime);
    }
    
    /**
     * @dev Cast vote on a proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _support True for yes, false for no
     */
    function vote(uint256 _proposalId, bool _support) external onlyRegisteredVoter validProposal(_proposalId) {
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted on this proposal");
        require(voters[msg.sender].votingPower > 0, "No voting power (may have delegated)");
        
        proposals[_proposalId].hasVoted[msg.sender] = true;
        uint256 votingPower = voters[msg.sender].votingPower;
        
        if (_support) {
            proposals[_proposalId].yesVotes += votingPower;
        } else {
            proposals[_proposalId].noVotes += votingPower;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }
    
    // View functions
    function getProposal(uint256 _proposalId) external view returns (
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 endTime,
        bool executed
    ) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.endTime,
            proposal.executed
        );
    }
    
    function getVoterInfo(address _voter) external view returns (
        bool isRegistered,
        address delegate,
        uint256 votingPower
    ) {
        Voter storage voter = voters[_voter];
        return (
            voter.isRegistered,
            voter.delegate,
            voter.votingPower
        );
    }
    
    function getDelegatedBy(address _delegate) external view returns (address[] memory) {
        return delegatedBy[_delegate];
    }
    
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }
}
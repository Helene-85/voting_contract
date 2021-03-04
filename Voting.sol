// Voting.sol
// SPDX-License-Identifier:  GPL-3.0
pragma solidity 0.8.0;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    
    struct Voter {
        bool isRegistered;
        bool hasVoted; 
        uint16 votedProposalId;
        bool isAbleToPropose; // Ajout
        bool hasProposed; // Ajout
    }
    
    struct Proposal {
        string description;
        uint16 voteCount;
        address author; // Ajout
        bool isActive;
    }
    
    struct Session {
        string name;  
        uint nbVoters;
        uint nbProposals;
        uint nbAllVotes;
        uint startTimeSession;  
        uint endTimeSession;  
        Proposal winningProposal;        
    }
 
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
 
    event VoterRegistered(address voterAddress);
    event VoterUnRegistered(address voterAddress); // ajout    
    event ProposalsRegistrationStarted();
    event ProposalsRegistrationEnded();
    event ProposalRegistered(uint proposalId);
    event VotingSessionStarted();
    event VotingSessionEnded();
    event Voted (address voter, uint proposalId);
    event VotesTallied();
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    
    mapping(uint16 => mapping(address => Voter)) public voters;
    address[] private AddressToSave;
    Proposal[] public proposals;
    Session[] public sessions;
    
    uint16 public winningProposalId;
    uint16 public sessionId;
    uint16 private maxVoters;
    uint16 private maxProposals;
    WorkflowStatus public currentStatus;

     /*
    L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    L'administrateur du vote commence la session d'enregistrement de la proposition.
    Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    L'administrateur de vote met fin à la session d'enregistrement des propositions.
    L'administrateur du vote commence la session de vote.
    Les électeurs inscrits votent pour leurs propositions préférées.
    L'administrateur du vote met fin à la session de vote.
    L'administrateur du vote comptabilise les votes.
    Tout le monde peut vérifier les derniers détails de la proposition gagnante.
     */
     
    constructor(uint16 _maxVoters, uint16 _maxProposals){
        maxVoters = _maxVoters;
        maxProposals = _maxProposals;        
        sessionId = 1;
        sessions[sessionId] = Session("NA", 0, 0, 0, 0, 0, Proposal("NA", 0, address(0), true));
        currentStatus = WorkflowStatus.RegisteringVoters;
        proposals.push(Proposal('Blank Vote', 0, address(0), true)); //Ca evite aussi de s'ennuyer avec un id qui commence à 0 dans le tableau
    }
    
    //L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function addVoter(address _addressVoter, bool _isAbleToPropose) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");        
        require(sessions[sessionId].nbVoters < maxVoters, "Max voters reached");
        require(!voters[sessionId][_addressVoter].isRegistered, "Voter already registred");

        voters[sessionId][_addressVoter] = Voter(true, false, 0, _isAbleToPropose, false);
        sessions[sessionId].nbVoters ++;
        
        emit VoterRegistered(_addressVoter);
    }

    //L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function removedVoter(address _addressVoter) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");        
        require(voters[sessionId][_addressVoter].isRegistered, "Voter not registred");
        
        voters[sessionId][_addressVoter].isRegistered = false;
        sessions[sessionId].nbVoters --;
        
        emit VoterUnRegistered(_addressVoter);
    }

    //L'administrateur du vote commence la session d'enregistrement de la proposition.
    function proposalSessionBegin(string memory _name) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");
        
        sessions[sessionId].name = _name;
        sessions[sessionId].startTimeSession = block.timestamp;
        
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
        emit ProposalsRegistrationStarted();        
    }
    
    //Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function addProposal(string memory _content) external {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not ProposalsRegistrationStarted Status");
        require(voters[sessionId][msg.sender].isRegistered, "Voter not registred");
        require(voters[sessionId][msg.sender].isAbleToPropose, "Voter not exist or not proposer");
        require(!voters[sessionId][msg.sender].hasProposed, "Voter has already proposed");
        require(sessions[sessionId].nbProposals < maxProposals, "Max proposals reached");

        voters[sessionId][msg.sender].hasProposed = true;
        proposals.push(Proposal(_content, 0, msg.sender, true));
        sessions[sessionId].nbProposals ++;
        
        emit ProposalRegistered(sessions[sessionId].nbProposals);
    }    

    //L'administrateur de vote met fin à la session d'enregistrement des propositions.
    function proposalSessionEnded() external onlyOwner{
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not ProposalsRegistrationStarted Status");
        
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
        emit ProposalsRegistrationEnded();        
    }
    
    //L'administrateur du vote commence la session de vote.
    function votingSessionStarted() external onlyOwner{
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Not ProposalsRegistrationEnded Status");
        
        currentStatus = WorkflowStatus.VotingSessionStarted;
        
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
        emit VotingSessionStarted();        
    }    
    
    // Les électeurs inscrits votent pour leurs propositions préférées.    
    function addVote(uint16 _votedProposalId) external {
        require(voters[sessionId][msg.sender].isRegistered, "Voter can vote");
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Time to vote!");
        require(proposals[_votedProposalId].isActive);
        
        voters[sessionId][msg.sender].votedProposalId = _votedProposalId;
        voters[sessionId][msg.sender].hasVoted = true;
        proposals[_votedProposalId].voteCount ++;
        
        emit Voted (msg.sender, _votedProposalId);
    }


    //L'administrateur du vote met fin à la session de vote.     
      function votingSessionEnded() external onlyOwner{
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "The end!");
        
        currentStatus = WorkflowStatus.VotingSessionEnded;
        
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.ProposalsRegistrationEnded);
        emit VotingSessionEnded();        
    }    
    
     
     
    // L'administrateur du vote comptabilise les votes.
    
    // Récupérer nbAllVotes par proposal ????
    
    // Choisir la proposition gagnante, avec en cas d'égalité la proposition la plus vieille
    function bestProposal() external onlyOwner{
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "The end!");
        
        currentStatus  = WorkflowStatus.VotesTallied;
        
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        emit VotesTallied();
    }
    
    
     
    // Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    // Un get sur les résultats de la session
    function getDetailsAboutTheWinner() {
        require(currentStatus == WorkflowStatus.VotesTallied, "Votes tallied!");
        
    }


    // Nous ferons tous les trois, la fonctionnalité qui relance une nouvelle session !!



     
} 
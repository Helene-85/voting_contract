// Voting.sol
// SPDX-License-Identifier:  GPL-3.0
pragma solidity 0.8.0;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    
    struct Voter {
        bool isRegistered;
        bool hasVoted; 
        uint16 votedProposalId;
    }
    
    struct Proposal {
        string description;
        uint16 voteCount;
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
    
    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    uint16 proposalWinningId;

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
     
    constructor(){
        currentStatus = WorkflowStatus.RegisteringVoters;
    }
    
    //L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function addVoter(address _addressVoter) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");        
        require(!voters[_addressVoter].isRegistered, "Voter already registred");

        voters[_addressVoter] = Voter(true, false, 0);

        emit VoterRegistered(_addressVoter);
    }

    //L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function removedVoter(address _addressVoter) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");        
        require(voters[_addressVoter].isRegistered, "Voter not registred");
        
        voters[_addressVoter].isRegistered = false;

        emit VoterUnRegistered(_addressVoter);
    }

    //L'administrateur du vote commence la session d'enregistrement de la proposition.
    function proposalSessionBegin() external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");
        
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
        emit ProposalsRegistrationStarted();        
    }
    
    //Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function addProposal(string memory _content) external {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not ProposalsRegistrationStarted Status");
        require(voters[msg.sender].isRegistered, "Voter not registred");

        proposals.push(Proposal(_content, 0));
        uint proposalId = proposals.length-1;

        emit ProposalRegistered(proposalId);
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
        require(voters[msg.sender].isRegistered, "Voter can vote");
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Time to vote!");

        voters[msg.sender].votedProposalId = _votedProposalId;
        voters[msg.sender].hasVoted = true;
        proposals[_votedProposalId].voteCount++;

        emit Voted (msg.sender, _votedProposalId);
    }
    
    //L'administrateur du vote met fin à la session de vote.     
    function votingSessionEnded() external onlyOwner{
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Not ProposalsRegistrationEnded Status");
        
        currentStatus = WorkflowStatus.VotingSessionEnded;
        
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
        emit VotingSessionEnded();        
    }       
    
     
    // L'administrateur du vote comptabilise les votes. 
    // Choisir la proposition gagnante, avec en cas d'égalité la proposition la plus vieille    
    function votesTallied() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "Session is still ongoing");
        
        currentStatus = WorkflowStatus.VotesTallied;
        
        uint16 currentWinnerId = 0;
        uint16 nbVotesWinner = 0;

        for(uint16 i=uint16(proposals.length-1); i>0; i--){
            if (proposals[i].voteCount > nbVotesWinner){
                currentWinnerId = i;
                nbVotesWinner = proposals[i].voteCount;
            }
        }
        proposalWinningId = currentWinnerId;
   

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        emit VotesTallied();
    }

    // Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    // Un get sur les résultats de la session
    function getWinningProposal() external view returns(string memory contentProposal){
        require(currentStatus == WorkflowStatus.VotesTallied, "Acces DENIED"); 
        return (proposals[proposalWinningId].description);
    }
 
} 
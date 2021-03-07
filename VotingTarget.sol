// Voting.sol
// SPDX-License-Identifier:  GPL-3.0
pragma solidity 0.8.0;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

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

contract Voting is Ownable {
    
    struct Voter {                                                          // Mise en place de le structure des voteurs
        bool isRegistered;
        bool hasVoted; 
        uint16 votedProposalId;
        bool isAbleToPropose;                                               // FEATURE V2
        bool hasProposed;                                                   // FEATURE V2
    }
    
    struct Proposal {                                                       // Mise en place de la strcuture des propositions
        string description;
        uint16 voteCount;
        address author;                                                     // FEATURE V2
        bool isActive;                                                      // FEATURE V2
    }
    
    struct Session {                                                        // Mise en place de la structure des sessions - FEATURE V2
        string name;  
        uint16 nbVoters;
        uint16 nbProposals;
        uint16 nbAllVotes;
        uint startTimeSession;  
        uint endTimeSession;  
        uint16 winningProposalId;
    }
 
    enum WorkflowStatus {                                       // Énumération des différentes étapes des sessions
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
 
    event VoterRegistered(address voterAddress);
    event VoterUnRegistered(address voterAddress);                          // FEATURE V2    
    event ProposalsRegistrationStarted();
    event ProposalsRegistrationEnded();
    event ProposalRegistered(uint proposalId);
    event ProposalRejected(uint proposalId);                                // FEATURE V2
    event VotingSessionStarted();
    event VotingSessionEnded();
    event Voted (address voter, uint proposalId);
    event VotesTallied();
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    
    uint16 public sessionId;                                                                    // FEATURE V2 : Identifiant de la Session de vote en cours
    
    Session[] public sessions;                                                                  // FEATURE V2
    mapping(uint => mapping(address => Voter)) public voters;                                   // Un mapping de voters par sessionId
    address[][] private addressToSave;                                                          // Sauvegarde des adresses des voters de manière à pouvoir boucler sur le mapping                                                     
    Proposal[][] public proposals;                                                              // Tableau de propositions par sessionId

    uint16 public maxVoters;                                                                    // On détermine le nb max de voters
    uint16 public maxProposals;                                                                 // On détermine le nb max de propositions
    WorkflowStatus public currentStatus;                                                        /* Stade en cours de la session (tableau inutile) Idée V3 = plusieurs sessions en même tps 
                                                                                                    => tableau pour gérer les statuts des diff sessions */
                                                                                                    

    constructor(uint16 _maxVoters, uint16 _maxProposals){
        maxVoters = _maxVoters;
        maxProposals = _maxProposals;        
        sessionId = 1;
        sessions[sessionId] = Session("NC", 0, 0, 0, 0, 0, 0);
        currentStatus = WorkflowStatus.RegisteringVoters;
        proposals[sessionId].push(Proposal('Blank Vote', 0, address(0), true));                 // Rajouter la proposition de vote nul
    }
    
    // L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function addVoter(address _addressVoter, bool _isAbleToPropose) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");        
        require(sessions[sessionId].nbVoters < maxVoters, "Max voters reached");
        require(!voters[sessionId][_addressVoter].isRegistered, "Voter already registred");

        voters[sessionId][_addressVoter] = Voter(true, false, 0, _isAbleToPropose, false);
        sessions[sessionId].nbVoters++;
        addressToSave[sessionId].push(_addressVoter);
        
        emit VoterRegistered(_addressVoter);
    }

    // L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function removeVoter(address _addressVoter) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");        
        require(voters[sessionId][_addressVoter].isRegistered, "Voter not registred");
        
        voters[sessionId][_addressVoter].isRegistered = false;
        sessions[sessionId].nbVoters --;
        
        emit VoterUnRegistered(_addressVoter);
    }

    // L'administrateur du vote commence la session d'enregistrement de la proposition.
    function proposalSessionBegin(string memory _name) external onlyOwner{
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Not RegisteringVoters Status");
        
        sessions[sessionId].name = _name;
        sessions[sessionId].startTimeSession = block.timestamp;
        
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
        emit ProposalsRegistrationStarted();        
    }
    
    // Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function addProposal(string memory _content) external {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not ProposalsRegistrationStarted Status");
        require(voters[sessionId][msg.sender].isRegistered, "Voter not registred");
        require(voters[sessionId][msg.sender].isAbleToPropose, "Voter not a proposer");
        require(!voters[sessionId][msg.sender].hasProposed, "Voter has already proposed");
        require(sessions[sessionId].nbProposals < maxProposals, "Max proposals reached");

        voters[sessionId][msg.sender].hasProposed = true;
        proposals[sessionId].push(Proposal(_content, 0, msg.sender, true));
        sessions[sessionId].nbProposals++;
        
        emit ProposalRegistered(sessions[sessionId].nbProposals);                                       // Le nb de propositions est égal à l'id de la proposition, cf. vote nul
    }    

    // L'administrateur de vote met fin à la session d'enregistrement des propositions.
    function proposalSessionEnded() external onlyOwner{
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not ProposalsRegistrationStarted Status");
        
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
        emit ProposalsRegistrationEnded();        
    }
    
    // Refus de proposition
    function refuseProposal(uint16 _proposalId) external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Not ProposalsRegistrationEnded Status");
        require(proposals[sessionId][_proposalId].isActive, "Proposal has already been rejected");

        proposals[sessionId][_proposalId].isActive = false;

        emit ProposalRejected(_proposalId);                                                             // Idea V3 : ajout de la possibilité de réactivier la proposition
    }
    
    
    // L'administrateur du vote commence la session de vote.
    function votingSessionStarted() external onlyOwner{
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Not ProposalsRegistrationEnded Status");
        
        currentStatus = WorkflowStatus.VotingSessionStarted;
        
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
        emit VotingSessionStarted();        
    }    
    
    // Les électeurs inscrits votent pour leurs propositions préférées.    
    function addVote(uint16 _votedProposalId) external {
        require(voters[sessionId][msg.sender].isRegistered, "Voter can vote");
        require(!voters[sessionId][msg.sender].hasVoted, "Already voted");
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Time to vote!");
        require(proposals[sessionId][_votedProposalId].isActive);
        
        voters[sessionId][msg.sender].votedProposalId = _votedProposalId;
        voters[sessionId][msg.sender].hasVoted = true;
        proposals[sessionId][_votedProposalId].voteCount++;
        sessions[sessionId].nbAllVotes++;
        
        emit Voted (msg.sender, _votedProposalId);
    }
    
    // L'administrateur du vote met fin à la session de vote.     
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
        uint16 nbVotesWinner = proposals[sessionId][0].voteCount;

        for(uint16 i=0; i<(proposals.length-1); i++){
            if (proposals[sessionId][i].voteCount > nbVotesWinner){
                currentWinnerId = i;
                nbVotesWinner = proposals[sessionId][i].voteCount;
            }
        }

        sessions[sessionId].winningProposalId = currentWinnerId;
        sessions[sessionId].endTimeSession = block.timestamp;        

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        emit VotesTallied();
    }

    // Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    // Un get sur les résultats de la session
    function getWinningProposal(uint16 _sessionId) external view returns(string memory contentProposal, address winnerAddress, uint16 nbVotes, uint16 nbAllVotes){
        require( ((_sessionId == sessionId) && (currentStatus == WorkflowStatus.VotesTallied)) || (_sessionId < sessionId), "Acces DENIED"); 
        
        return (
            proposals[_sessionId][sessions[_sessionId].winningProposalId].description,
            proposals[_sessionId][sessions[_sessionId].winningProposalId].author,
            proposals[_sessionId][sessions[_sessionId].winningProposalId].voteCount,
            sessions[_sessionId].nbAllVotes
        );
    }
    
    // On démarre une nouvelle session
    function beginNewSession(bool saveVoters, bool savePropals) external onlyOwner {
        require(currentStatus == WorkflowStatus.VotesTallied, "It's time to start a new session");      
        
        sessionId++;   
        currentStatus = WorkflowStatus.RegisteringVoters;         
        sessions[sessionId] = Session("NC", 0, 0, 0, 0, 0, 0);                                          // On intitialise une nouvelle session avec les compteurs à 0
        proposals[sessionId].push(Proposal('Blank Vote', 0, address(0), true));  
        uint16 preSessionId = sessionId-1;
        
        if(saveVoters)                                                                                  // On garde les voters de la session précédente
        {
            bool _isAbleToPropose;                                                                      // Ils peuvent de nouveau faire des propositions

            for(uint16 i=0; i<addressToSave[preSessionId].length; i++){
                _isAbleToPropose = voters[preSessionId][addressToSave[preSessionId][i]].isAbleToPropose;
                voters[sessionId][addressToSave[preSessionId][i]] = Voter(true, false, 0, _isAbleToPropose, false);
                addressToSave[sessionId].push(addressToSave[preSessionId][i]);            
            }                  
        }

        if(savePropals)
        {
            for(uint16 i=0; i<proposals[preSessionId].length; i++){
                proposals[sessionId][i] = proposals[preSessionId][i];
                proposals[sessionId][i].voteCount = 0;
            }                  
        }

    }  

} 
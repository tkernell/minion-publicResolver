pragma solidity 0.5.12;

import "https://github.com/raid-guild/moloch-minion/blob/develop/contracts/moloch/Moloch.sol";

contract PublicResolver {
    
    function isAuthorised(bytes32 node) internal view returns(bool);
    
    modifier authorised(bytes32 node) {
        require(isAuthorised(node));
        _;
    }
    function setContenthash(bytes32 node, bytes calldata hash) external authorised(node) {}

    function contenthash(bytes32 node) external view returns (bytes memory) {}
}

contract MinionPublicResolver {
    string public constant MINION_ACTION_DETAILS = '{"isMinion": true, "title":"MINION", "description":"';
    
    Moloch public moloch;
    PublicResolver public publicResolver;
    address public molochApprovedToken;
    mapping (uint256 => Action) public actions; // proposalId => Action

    struct Action {
        bytes32 node;
        bytes hash;
        address proposer;
        bool executed;
    }

    event ActionProposed(uint256 proposalId, address proposer);
    event ActionExecuted(uint256 proposalId, address executor);

    constructor(address _moloch, address _publicResolver) public {
        moloch = Moloch(_moloch);
        molochApprovedToken = moloch.depositToken();
        publicResolver = PublicResolver(_publicResolver);
    }
    
    function proposeSetContenthash(bytes32 _node, bytes memory _hash, string memory _description) public returns(uint256) {
        string memory details = string(abi.encodePacked(MINION_ACTION_DETAILS, _description, '"}'));
        uint256 proposalId = moloch.submitProposal(
            address(this),
            0,
            0,
            0,
            molochApprovedToken,
            0,
            molochApprovedToken,
            details
        );
        
        Action memory action = Action({
            node: _node,
            hash: _hash,
            proposer: msg.sender,
            executed: false
        });

        actions[proposalId] = action;

        emit ActionProposed(proposalId, msg.sender);
        return proposalId;
    }

    // Returns new content hash
    function executeSetContentHash(uint256 _proposalId) public returns(bytes memory) {
        Action memory action = actions[_proposalId];
        bool[6] memory flags = moloch.getProposalFlags(_proposalId);

        // minion did not submit this proposal
        // require(action.to != address(0), "Minion::invalid _proposalId");
        // can't call arbitrary functions on parent moloch
        // require(action.to != address(moloch), "Minion::invalid target");
        require(!action.executed, "Minion::action executed");
        // require(address(this).balance >= action.value, "Minion::insufficient eth");
        require(flags[2], "Minion::proposal not passed");

        // execute call
        actions[_proposalId].executed = true;
        publicResolver.setContenthash(action.node, action.hash);
        emit ActionExecuted(_proposalId, msg.sender);
        return(publicResolver.contenthash(action.node));
    }

}

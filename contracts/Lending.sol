pragma solidity ^0.4.23;

contract JioToken {
    
    uint256 public totalSupply;

    function balanceOf(address _owner) public view returns (uint256 balance);
    
    function transfer(address _to, uint256 _value) public returns (bool success);

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    function approve(address _spender, uint256 _value) public returns (bool success);

    function allowance(address _owner, address _spender) public view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Lend {
    
    enum LoanStatus { APPROVED, REJECTED, SUBMITTED, REQUESTED, REPAYED, ACTIVE, DELETED }
    
    address jioTokenAddress;
    
    struct PersonInfo {
        string aadharNumber;
        string name;
        uint dob;
        string homeAddress;
    }
    
    struct Proposal {
        string loanID;
        address borrower;
        uint32 amount;
        uint interestRate;
        uint duration;
        LoanStatus status;
    }
    
    
    mapping (address => uint) rewardPoints;
    mapping (address => PersonInfo) users;
    mapping (address => mapping(string => Proposal)) lenderProposals;
    
    
    event Register(address, string, string, uint, string);
    event SubmitLoanProposal(address, string, uint, uint32, uint);
    event ApproveLoan(string, address, address, uint);
    event RejectLoan(string, address);
    event RepayLoan(address, address, uint, uint);
    event DeleteProposal(address, string, uint);
    event RequestLoan(address, string, address); 
    
    modifier validAddress(address _address) {
        require(_address != address(0));
        _;
    }
    
    constructor (address _jioTokenAddress) public {
        jioTokenAddress = _jioTokenAddress;
    }
    
    function register(string _aadharNumber, string _name, uint _dob, string _homeAddress) public {
        users[msg.sender].aadharNumber = _aadharNumber;
        users[msg.sender].name = _name;
        users[msg.sender].dob = _dob;
        users[msg.sender].homeAddress = _homeAddress;
        
        emit Register(msg.sender, _aadharNumber, _name, _dob, _homeAddress);
    }
    
    function getUserInfo(address userKey) public view returns(string, string, uint, string, uint) {
        return(users[userKey].aadharNumber, users[userKey].name, users[userKey].dob, users[userKey].homeAddress, rewardPoints[msg.sender]);
    }
    
    function submitLoanProposal(string _loanID, uint32 _amount, uint _interestRate, uint _duration) public {
        JioToken token = JioToken(jioTokenAddress);
        
        require((token.balanceOf(msg.sender) >= _amount) && _duration > 0);
        
        Proposal memory proposal;
    
        proposal.loanID = bytes32ToString(keccak256(_loanID));
        proposal.interestRate = _interestRate;
        proposal.amount = _amount;
        proposal.duration = now + _duration;
        proposal.status = LoanStatus.SUBMITTED;
        
        lenderProposals[msg.sender][proposal.loanID] = proposal;
            
        emit SubmitLoanProposal(msg.sender, proposal.loanID, proposal.interestRate, proposal.amount, proposal.duration);
    }
    
    function approveLoan(string _loanID, address _borrower, uint _interestRate) public validAddress(_borrower) {
        JioToken token = JioToken(jioTokenAddress);
        
        Proposal memory proposal = lenderProposals[msg.sender][_loanID];
        
        require((token.balanceOf(msg.sender) >= proposal.amount) 
        && proposal.duration > now 
        && proposal.status == LoanStatus.REQUESTED);
        
        lenderProposals[msg.sender][_loanID].status = LoanStatus.APPROVED;
        
        require(token.transferFrom(msg.sender, _borrower, proposal.amount));
        
        emit ApproveLoan(_loanID, msg.sender, _borrower, _interestRate);
    }
    
    function rejectLoan(string _loanID) public {
        Proposal memory proposal = lenderProposals[msg.sender][_loanID];
        
        require( proposal.duration > now && proposal.status == LoanStatus.REQUESTED);
        
        lenderProposals[msg.sender][_loanID].status = LoanStatus.REJECTED;
        
        emit RejectLoan(_loanID, msg.sender);
    }
    
    function repayLoan(string _loanID, address _lender, uint repayAmount) public validAddress(_lender){
        JioToken token = JioToken(jioTokenAddress);
        
        Proposal memory proposal = lenderProposals[_lender][_loanID];

        require((token.balanceOf(msg.sender) >= repayAmount) 
        && proposal.duration > now 
        && proposal.status == LoanStatus.REQUESTED);
        
        if(proposal.duration > now) {
            rewardPoints[msg.sender] += 1;
        }
        
        lenderProposals[_lender][_loanID].status = LoanStatus.REPAYED;
        require(token.transferFrom(msg.sender, _lender, repayAmount));
        
        emit RepayLoan(msg.sender, _lender, repayAmount, now);
    }
    
    function deleteProposal(string _loanID) public {
        delete lenderProposals[msg.sender][_loanID];
        
        emit DeleteProposal(msg.sender, _loanID, now);
    }
    
    function requestLoan(string _loanID, address _lender) public validAddress(_lender){
        require(msg.sender != _lender);
        lenderProposals[_lender][_loanID].borrower = msg.sender;
        lenderProposals[_lender][_loanID].status = LoanStatus.REQUESTED;
        
        emit RequestLoan(msg.sender, _loanID, _lender);
    }
    
    function toBytesFromAddress(address a) internal pure returns (bytes b) {
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
            mstore(0x40, add(m, 52))
            b := m
        }
    }
    
    function toBytesFromUint(uint256 x) internal pure returns (bytes b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }
    
    function bytes32ToString (bytes32 data) internal pure returns (string) {
        bytes memory bytesString = new bytes(32);
        for (uint j=0; j<32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
            }
        }
        return string(bytesString);
    }
    
      function() public{
        revert();
    }
}
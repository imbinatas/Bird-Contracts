pragma solidity ^0.6.0;

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// rank
// 1 -> client
// 2 -> leader
// 3 -> totalAmbassadorIncomeWithdrawn

contract C4K{
    using SafeMath for uint256;
    address public owner;
    uint256 constant MAX_PROFIT = 11991;   // 119.11991
    uint256 constant MAX_PRINCIPLE = 300;  // 300%
    uint256 constant AMBASSADOR_DIRECT_PERCENT =2940;  // 1.4 every month --> 29.4
    uint256 constant AMBASSADOR_INDIRECT_PERCENT = 630;  // 6.3 every month  --> 0.3 every month
    uint256 constant LEADER_PERCENT = 2310; // 23.1  --> 1.1 every month
    uint256 constant ADMIN_DIRECT_PERCENT =  3780;  // 37.8  --> 1.8 every month   
    uint256 constant ADMIN_INDIRECT_PERCENT = 840;  // 8.4  --> 0.4 every month
    uint256 constant PROFIT_MONTHY = 571; // 5.71
    uint256 constant ADMIN_DIRECT_MONTHLY = 180;  // 1.8
    uint256 constant ADMIN_INDIRECT_MONTHLY = 40;  // 0.40
    uint256 constant LEADER_MONTHLY = 110; // 1.1
    uint256 constant AMBASSADOR_DIRECT_MONTHLY = 140;  // 1.4
    uint256 constant AMBASSADOR_INDIRECT_MONTHLY = 30; // 0.3
    uint256 constant MONTH = 1;   //263520-->1 month secs
    
    IERC20 public NWT;
    IERC20 public NTT;
    uint256 public ownerAmount;
    
    uint256 public totalUsers;
    
    struct Deposit{
        uint256 amount;
        uint256 start;
        uint256 profitStart;
        uint256 withdrawnProfit;
        uint256 principleStart;
        uint256 withdrawnPrinciple;
        uint256 principleTimestamp;
        uint256 profitTimestamp;
    }
    
    struct User{
        uint256 id;
        Deposit[] deposits;
        uint256 totalReferrers;
        uint256 totalLeaders;
        uint256 rank;
        bool isExist;
        address referrer;
        uint256 ambassadorDirectProfit;
        uint256 leaderDirectProfit;
        uint256 ambassadorInDirectProfit;
        uint256 referralWithdrawnTime;
    }
    
    struct UserWithdrawnInfo{
        uint256 totalProfitWithdrawn;
        uint256 totalPrincipleWithdrawn;
        uint256 totalReferralIncomeWithdrawn;
    }
    
    modifier onlyAdmin{
        require(msg.sender == owner);
        _;
    }
    
    uint256[] public profitPercents;
    uint256 public totalInvestedTokens;
    mapping(address=>User) public users;
    mapping(address=>UserWithdrawnInfo) public withdrawns;
    
    event NewUserEntered(address _user,address _ref,uint256 _amount);
    event withdrawPrincipleEvent(address _user,uint256 _amount,uint256 _lastWithdraw,uint256 _curr,uint256 _diff);
   
    event withdrawProfitEvent(address _user,uint256 _amount,uint256 _lastWithdraw,uint256 _curr,uint256 _diff);
    event withdrawIssueEvent(address _user,uint256 _amount,uint256 _lastWithdraw,uint256 _curr,uint256 _diff);
    event referralIncome(address _user, uint256 _amount, uint256 _start,uint256 _now, uint256 _diff);
    
    constructor(IERC20 _addrA,IERC20 _addrB) public{
        NWT = _addrA;
        NTT = _addrB;
        owner = msg.sender;
        profitPercents.push(11);
        profitPercents.push(4);
        profitPercents.push(3);    
    }
    
    /*
    ------------------------------------------------------------------------>
     internal  functions
    ------------------------------------------------------------------------>
    */
    
    function _invest(address _ref,uint256 _amount) internal{
        require(NWT.allowance(msg.sender,address(this))>=_amount, "You must allow contract first to pay on your behalf");
        
        NWT.transferFrom(msg.sender,address(this),_amount);
        if(_ref==address(0) || users[_ref].isExist==false || _ref == msg.sender){
            _ref=owner;
        }
        
        if(msg.sender == owner){
            _ref=address(0);
        }
        
        
        if(users[msg.sender].deposits.length==0){
            // new user
            users[msg.sender].referrer = _ref;
            users[msg.sender].isExist = true;
            users[_ref].totalReferrers = users[_ref].totalReferrers.add(1);
            totalUsers = totalUsers.add(1);
            users[msg.sender].id=totalUsers;
            users[msg.sender].rank = 1;
            users[msg.sender].referralWithdrawnTime = block.timestamp;
            emit NewUserEntered(msg.sender,_ref,_amount);
        }
        
        users[msg.sender].deposits.push(Deposit(_amount,block.timestamp,
        block.timestamp.add(MONTH.mul(4)),0,
        block.timestamp.add(MONTH.mul(12)),0,block.timestamp.add(MONTH.mul(12)),
        block.timestamp.add(MONTH.mul(4))));
        
        _ref = users[msg.sender].referrer;
        
         // 1.8% to owner every month --> 37.8
        ownerAmount = ownerAmount.add(_amount.mul(ADMIN_DIRECT_PERCENT).div(10000));
        
        if(users[_ref].totalReferrers>=2 && users[_ref].rank<2){
            users[_ref].rank = 2;
            users[users[_ref].referrer].totalLeaders = users[users[_ref].referrer].totalLeaders.add(1);
            if(users[users[_ref].referrer].totalLeaders>=2){
                users[users[_ref].referrer].rank = 3;
            }
        }
            // From Direct Sale
            
           
            // if referrer is ambassador then give 1.4 every month till 24 months --> 29.4
            if(users[_ref].rank == 3){
                users[_ref].ambassadorDirectProfit = users[_ref].ambassadorDirectProfit.add(_amount.mul(AMBASSADOR_DIRECT_PERCENT).div(10000));
            }
            
            // if referrer is leader then give 1.1 every month till 24 months --> 23.1
            if(users[_ref].rank == 2)
            {
                users[_ref].leaderDirectProfit = users[_ref].leaderDirectProfit.add(_amount.mul(LEADER_PERCENT).div(10000));
            }
            
            /* From Indirect Sale
            
            If referrer is leader and referrer of leader is ambassador, 
            ambassador will get 0.3% every month --> 6.31
            and c4k admin will get 0.4% every month --> 8.4
            
            */
            if(users[_ref].rank == 2 && users[users[_ref].referrer].rank == 3){
                users[users[_ref].referrer].ambassadorInDirectProfit = users[users[_ref].referrer].ambassadorInDirectProfit
                .add(_amount.mul(AMBASSADOR_INDIRECT_PERCENT).div(10000));
                
                ownerAmount = ownerAmount.add(_amount.mul(ADMIN_INDIRECT_PERCENT).div(10000));
                
            }
        
    }
    
    function getProfit(address _user) internal  returns(uint256){
        uint256 amount;
        uint256 totalAmount;
        for(uint256 i=0;i<users[_user].deposits.length;i++){
            if(block.timestamp>=users[_user].deposits[i].profitStart){
                if(users[_user].deposits[i].withdrawnProfit<users[_user].deposits[i].amount.mul(MAX_PROFIT).div(10000)){
                    amount = (users[_user].deposits[i].amount.mul(PROFIT_MONTHY).mul(block.timestamp.sub(users[_user].deposits[i].profitTimestamp))).div(10000).div(MONTH);
                }
                if(users[_user].deposits[i].withdrawnProfit.add(amount)>=users[_user].deposits[i].amount.mul(MAX_PROFIT).div(10000)){
                    amount = (users[_user].deposits[i].amount.mul(MAX_PROFIT).div(10000)).sub(users[_user].deposits[i].withdrawnProfit);
                }
                totalAmount = totalAmount.add(amount);
            }
            emit withdrawProfitEvent(_user,amount,users[_user].deposits[i].profitTimestamp,
            block.timestamp, block.timestamp.sub(users[_user].deposits[i].profitTimestamp));
      
             if(amount>0){
                users[_user].deposits[i].profitTimestamp = block.timestamp;
            }
            users[_user].deposits[i].withdrawnProfit = users[_user].deposits[i].withdrawnProfit.add(amount);
              }
              withdrawns[_user].totalProfitWithdrawn = withdrawns[_user].totalProfitWithdrawn.add(amount);
     
        return totalAmount;
    }
    
    function getPrinciple(address _user) internal  returns(uint256){
        uint256 totalPrinciple;
        uint256 principle;
        for(uint256 i=0;i<users[_user].deposits.length;i++){
            if(block.timestamp<users[_user].deposits[i].principleStart)
            continue;
            if(block.timestamp>=users[_user].deposits[i].principleStart){
            if(users[_user].deposits[i].withdrawnPrinciple<users[_user].deposits[i].amount.mul(MAX_PRINCIPLE).div(100)){
                principle = (users[_user].deposits[i].amount.mul(block.timestamp.sub(users[_user].deposits[i].principleTimestamp))).div(MONTH.mul(6));
                if(users[_user].deposits[i].withdrawnPrinciple.add(principle)>=users[_user].deposits[i].amount.mul(MAX_PRINCIPLE).div(100)){
                    principle = (users[_user].deposits[i].amount.mul(MAX_PRINCIPLE).div(100)).sub(users[_user].deposits[i].withdrawnPrinciple);
                }
                users[_user].deposits[i].withdrawnPrinciple = users[_user].deposits[i].withdrawnPrinciple.add(principle);
                totalPrinciple = totalPrinciple.add(principle);
             }
            }
            emit withdrawPrincipleEvent(_user,principle,users[_user].deposits[i].principleTimestamp,
            block.timestamp, block.timestamp.sub(users[_user].deposits[i].principleTimestamp));
      
            if(principle>0){
                users[_user].deposits[i].principleTimestamp = block.timestamp;
            }
               }
        
        withdrawns[_user].totalPrincipleWithdrawn = withdrawns[_user].totalPrincipleWithdrawn.add(totalPrinciple);
     
        return totalPrinciple;
    }
    
    // profit + principle
    function getWithdrawAbleAmount(address _user) internal returns(uint256){
        uint256 amount;
        amount = getPrinciple(_user).add(getProfit(_user));
        return amount;
    }
    
    // direct and indirect incomes
    function getWithdrawableReferralIncome(address _user) internal  returns(uint256){
        uint256 amount1;
        uint256 amount2;
        uint256 amount3;
        
        require(block.timestamp.sub(users[_user].referralWithdrawnTime)>=MONTH,"You can withdraw again only after 1 month");
        
        amount1 = users[_user].leaderDirectProfit.mul(LEADER_MONTHLY).div(10000).mul(block.timestamp
        .sub(users[_user].referralWithdrawnTime)).div(MONTH);
        if(amount1>=users[_user].leaderDirectProfit)
        {
            amount1 = users[_user].leaderDirectProfit;
        }
        users[_user].leaderDirectProfit = users[_user].leaderDirectProfit.sub(amount1);
        
        
        amount2 = users[_user].ambassadorDirectProfit.mul(AMBASSADOR_DIRECT_MONTHLY).div(10000).mul(block.timestamp
        .sub(users[_user].referralWithdrawnTime)).div(MONTH);
        if(amount2>=users[_user].ambassadorDirectProfit)
        {
            amount2 = users[_user].ambassadorDirectProfit;
        }
        users[_user].ambassadorDirectProfit = users[_user].ambassadorDirectProfit.sub(amount2);
        
        
        amount3 = users[_user].ambassadorInDirectProfit.mul(AMBASSADOR_INDIRECT_MONTHLY).div(10000).mul(block.timestamp
        .sub(users[_user].referralWithdrawnTime)).div(MONTH);
        if(amount3>=users[_user].ambassadorInDirectProfit)
        {
            amount3 = users[_user].ambassadorInDirectProfit;
        }
        users[_user].ambassadorInDirectProfit = users[_user].ambassadorInDirectProfit.sub(amount3);
        
        
         emit referralIncome(_user,amount1.add(amount2).add(amount3),users[_user].referralWithdrawnTime,
        block.timestamp,block.timestamp.sub(users[_user].referralWithdrawnTime));
        
        users[_user].referralWithdrawnTime = block.timestamp;
       withdrawns[_user].totalReferralIncomeWithdrawn = withdrawns[_user].totalReferralIncomeWithdrawn.add(amount1.add(amount2).add(amount3));
     
        return amount1.add(amount2).add(amount3);
    }
    
    /*
    ------------------------------------------------------------------------>
     external setter functions
    ------------------------------------------------------------------------>
    */
    
    // invest
    function invest(address _ref,uint256 _amount) external{
        _invest(_ref,_amount);
    }
    
    // profits withdraw in NTT tokens  (mothly profit+referral Income (ambassador+leader)
    function withdrawProfits() external{
        uint256 amount = getWithdrawableReferralIncome(msg.sender).add(getProfit(msg.sender));
        NTT.transfer(msg.sender,amount);
    }
    
    // principle withdraw in NWT tokens
    function withdrawPrinciple() external{
        NWT.transfer(msg.sender,getPrinciple(msg.sender));
    }
    
    function withdrawOwnerAmount() external onlyAdmin{
        NTT.transfer(owner,ownerAmount);
        ownerAmount = 0;
    }
    
    
    /*
    ------------------------------------------------------------------------>
     Getter functions
    ------------------------------------------------------------------------>
    */
    
    function getProfitToBeWithdrawn(address _user) public view  returns(uint256){
        uint256 amount;
        uint256 totalAmount;
        for(uint256 i=0;i<users[_user].deposits.length;i++){
            if(block.timestamp>=users[_user].deposits[i].profitStart){
                if(users[_user].deposits[i].withdrawnProfit<users[_user].deposits[i].amount.mul(MAX_PROFIT).div(10000)){
                    amount = (users[_user].deposits[i].amount.mul(PROFIT_MONTHY).mul(block.timestamp.sub(users[_user].deposits[i].profitTimestamp))).div(10000).div(MONTH);
                }
                if(users[_user].deposits[i].withdrawnProfit.add(amount)>=users[_user].deposits[i].amount.mul(MAX_PROFIT).div(10000)){
                    amount = (users[_user].deposits[i].amount.mul(MAX_PROFIT).div(10000)).sub(users[_user].deposits[i].withdrawnProfit);
                }
                totalAmount = totalAmount.add(amount);
            }
        }
        return totalAmount;
    }
    
    function getPricipleToBeWithdrawn(address _user) public view  returns(uint256){
        uint256 totalPrinciple;
        uint256 principle;
        for(uint256 i=0;i<users[_user].deposits.length;i++){
            if(block.timestamp<users[_user].deposits[i].principleStart)
            continue;
            if(block.timestamp>=users[_user].deposits[i].principleStart){
            if(users[_user].deposits[i].withdrawnPrinciple<users[_user].deposits[i].amount.mul(MAX_PRINCIPLE).div(100)){
                principle = (users[_user].deposits[i].amount.mul(block.timestamp.sub(users[_user].deposits[i].principleTimestamp))).div(MONTH.mul(6));
                if(users[_user].deposits[i].withdrawnPrinciple.add(principle)>=users[_user].deposits[i].amount.mul(MAX_PRINCIPLE).div(100)){
                    principle = (users[_user].deposits[i].amount.mul(MAX_PRINCIPLE).div(100)).sub(users[_user].deposits[i].withdrawnPrinciple);
                }
                   totalPrinciple = totalPrinciple.add(principle);
             }
            }
           
               }
       
        return totalPrinciple;
    }
    
    function getReferralIncomeToBeWithdrawn(address _user) public view  returns(uint256){
        uint256 amount1;
        uint256 amount2;
        uint256 amount3;
        
        require(block.timestamp.sub(users[_user].referralWithdrawnTime)>=MONTH,"You can withdraw again only after 1 month");
        
        amount1 = users[_user].leaderDirectProfit.mul(LEADER_MONTHLY).div(10000).mul(block.timestamp
        .sub(users[_user].referralWithdrawnTime)).div(MONTH);
        if(amount1>=users[_user].leaderDirectProfit)
        {
            amount1 = users[_user].leaderDirectProfit;
        }
        
        amount2 = users[_user].ambassadorDirectProfit.mul(AMBASSADOR_DIRECT_MONTHLY).div(10000).mul(block.timestamp
        .sub(users[_user].referralWithdrawnTime)).div(MONTH);
        if(amount2>=users[_user].ambassadorDirectProfit)
        {
            amount2 = users[_user].ambassadorDirectProfit;
        }
        
        amount3 = users[_user].ambassadorInDirectProfit.mul(AMBASSADOR_INDIRECT_MONTHLY).div(10000).mul(block.timestamp
        .sub(users[_user].referralWithdrawnTime)).div(MONTH);
        if(amount3>=users[_user].ambassadorInDirectProfit)
        {
            amount3 = users[_user].ambassadorInDirectProfit;
        }
       
        
        return amount1.add(amount2).add(amount3);
    }
    
    function getReferralAmountToBeWithdrawn(address _user) public view returns(uint256){
        return (getReferralAmountToBeWithdrawn(_user).add(getProfitToBeWithdrawn(_user)));
    }
}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
    
        function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }
}

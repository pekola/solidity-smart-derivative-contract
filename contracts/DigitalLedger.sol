// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./SDCInceptor.sol";

contract DigitalLedger is IERC20 {

    uint256 private _totalSupply;
    string private name;
    string private symbol;

    address tokenManagerAddress;
    address sdcManagerAddress;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances; /*allowances for SDC*/

    modifier onlyTokenManager { // Modifier
        require(msg.sender==tokenManagerAddress,"Not authorised");//check wether msg.sender is an SDCTradeManager
        _;
    }

    modifier onlySDC { // Modifier
    
//        require(SDCManager(sdcManagerAddress).exists(msg.sender),"No registered active sdc address!");//check wether msg.sender is an SDCTradeManager
        _;
    }

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

//    event Transfer(address indexed from, address indexed to, uint256 value);
//    event Approval(address indexed owner, address indexed spender, uint256 value);

  /**  function bookMarginBuffers(address sdcToken) onlySDC external view  returns (bool){
        return true;
        /**
        1. grant allowance to token from both counterparties token balances from M and P
        2. book balances to tokens address
        3. grants futher allowance (of M) to token (to book settlement)
        
    }

    function bookSettlement(address sdcToken) onlySDC public  returns (bool) {
        1. SDCToken knows that it is triggered for valuation, and a settlement value is stored
        2. book settlement between account balances
        return true;
    }*/


    /** functions to be implemented from IERC20 Interface **/
    function totalSupply() external view override returns (uint256){
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256){
        require(account != address(0), "ERC20: mint to the zero address");
        require(account == msg.sender, "Not authorised");
        return balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256){
        require(1==1,"Only active trade contracts are allowed");
        // @todo: check whether spender is an active SDCToken
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool){  // Sets `amount` as the allowance of `spender` over the caller's tokens.
        require(msg.sender != address(0), "ERC20: approve to the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        require(1==1,"Only active trade contracts are allowed");
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 increasedAmount = allowance(owner, spender) + addedValue;
        allowances[owner][spender] = increasedAmount;
        emit Approval(owner, spender, increasedAmount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool){
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            balances[from] = fromBalance - amount;
        }
        balances[to] += amount;

        emit Transfer(from, to, amount);

        return true;

    }

    function transfer(address to, uint256 amount) external override returns (bool){
        return this.transferFrom(msg.sender,to,amount);
    }

    function mint(address account, uint256 amount) onlyTokenManager external virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);

    }

    function burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

  

}

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
        require(msg.sender==tokenManagerAddress,"Not authorised to mint token");//check wether msg.sender is an SDCTradeManager
        _;
    }

    modifier onlySDC { // Modifier
//        require(SDCManager(sdcManagerAddress).exists(msg.sender),"No registered active sdc address!");//check wether msg.sender is an SDCTradeManager
        _;
    }

    constructor(address _tokenManagerAddress, string memory name_, string memory symbol_) {
        tokenManagerAddress = _tokenManagerAddress;
        name = name_;
        symbol = symbol_;
    }


    /** functions to be implemented from IERC20 Interface **/
    function totalSupply() external view override returns (uint256){
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256){
//        require(account == msg.sender, "Digital Ledger: Not authorised");
        return balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256){
        // @todo: check whether spender is an active SDCToken
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool){
        require(msg.sender != address(0), "DigitalLedger: Zero Address");
        require(spender != address(0),  "DigitalLedger: Zero Address");
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address owner, address spender, uint256 addedValue) external returns (bool) {
        uint256 increasedAmount = this.allowance(owner, spender) + addedValue;
        allowances[owner][spender] = increasedAmount;
        emit Approval(owner, spender, increasedAmount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool){
        require(from != address(0), "DigitalLedger: Zero Address");
        require(to != address(0), "DigitalLedger: Zero Address");
        if ( from != msg.sender )
            require(allowances[from][msg.sender] >= amount, "DigitalLedger: Insufficient allowance");
        uint256 fromBalance = balances[from];
        require(fromBalance >= amount, "DigitalLedger: Insufficient Balance");
        balances[from] = fromBalance - amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool){
        return this.transferFrom(msg.sender,to,amount);
    }

    function mint(address account, uint256 amount) onlyTokenManager external virtual {
        require(account != address(0), "DigitalLedger: Zero Address");
        _totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) onlyTokenManager external virtual {
        require(account != address(0), "DigitalLedger: Zero Address");
        uint256 accountBalance = balances[account];
        require(accountBalance >= amount, "DigitalLedger: Insufficient Balance");
        balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

  

}

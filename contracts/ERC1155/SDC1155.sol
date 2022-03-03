// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/*  https://github.com/enjin/erc-1155/blob/master/contracts/IERC1155.sol
    https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol */

contract SDC1155 is IERC1155 {

    uint constant BUFFER = 1;
    uint constant MARGIN = 2;
    uint constant TERMINATIONFEE = 3;
    uint constant VALUATIONFEE = 4;

    enum TradeStatus{ INCEPTED, CONFIRMED, LIVE, TERMINATED }

    string private sdc_id;
    address private counterparty1Address;
    address private counterparty2Address;
    address private tokenManagerAddress;

    struct RefTradeSpec{
        uint256 trade_timestamp;
        string  fpml_data;
        TradeStatus tradeStatus;
        address adressFixedRatePayer;   // Convention is PV = Fix - Float
        address inceptionAddress;
        uint256 marginBuffer;
        uint256 terminationFee;
    }

    mapping(string => RefTradeSpec) refTradeSpecs;

    mapping(uint256 => mapping(address => uint256)) private balances;
    mapping(address => mapping(address => bool))    private operatorApprovals;

    event TradeIncepted(string id, uint256 timestamp);
    event TradeConfirmed(string id, uint256 timestamp);
    event TradeActive(string id, uint256 timestamp);
    event SDCTerminated(uint256 timestamp);
    event SDCSettlementSuccessful(uint256 timestamp);

     /* Modifiers */
    modifier onlyCounterparty { 
        require(msg.sender == counterparty1Address || msg.sender == counterparty2Address, "Not authorised"); _;
    }

    modifier onlyTokenManager { // Modifier
        require(msg.sender == tokenManagerAddress,"Not authorised");
        _;
    }
    

    constructor(string memory _sdc_id, 
                address _counterparty1Adress, 
                address _counterparty2Adress, 
                address _tokenManagerAddress) {
      sdc_id = _sdc_id; 
      counterparty1Address  = _counterparty1Adress;
      counterparty2Address  = _counterparty2Adress;  
      tokenManagerAddress   = _tokenManagerAddress;
    }

    
    function inceptTrade(string memory fpml_data, address fixPayerPartyAddress, uint256 terminationFee, uint256 marginBuffer) external onlyCounterparty returns(string memory){ 
        uint256 timestamp = block.timestamp;
        string memory trade_id = string(abi.encodePacked("trade_ref_",timestamp));
        refTradeSpecs[trade_id] = RefTradeSpec(timestamp,fpml_data,TradeStatus.INCEPTED,fixPayerPartyAddress,msg.sender,terminationFee,marginBuffer);
        emit TradeIncepted(trade_id,timestamp);
        return trade_id;
    }

    function confirmTrade(string memory trade_id) external onlyCounterparty  returns(bool){ 
        require(refTradeSpecs[trade_id].inceptionAddress != msg.sender, "Trade cannot be confirmed by inception address");
        refTradeSpecs[trade_id].trade_timestamp = block.timestamp;
        emit TradeConfirmed(trade_id,block.timestamp);
        _transfer(counterparty1Address, address(this), BUFFER, MARGIN, refTradeSpecs[trade_id].marginBuffer); 
        _transfer(counterparty1Address, address(this), BUFFER, TERMINATIONFEE, refTradeSpecs[trade_id].terminationFee); 
        _transfer(counterparty2Address, address(this), BUFFER, MARGIN, refTradeSpecs[trade_id].marginBuffer); 
        _transfer(counterparty2Address, address(this), BUFFER, TERMINATIONFEE, refTradeSpecs[trade_id].terminationFee); 
        emit TradeActive(trade_id,block.timestamp);
        return true;
    }


    
    function _performSettlement(string memory trade_id, uint256 settlement_amount, address address_of_creditor ) private returns(bool){
        require(settlement_amount > 0, "Settlement amount should be positive");
        require(address_of_creditor == counterparty1Address || address_of_creditor == counterparty2Address, "Creditor Address should be either CP1 oder CP");
        address address_of_debitor = address_of_creditor == counterparty1Address ? counterparty2Address : counterparty1Address;
        if ( _settlementCheck(trade_id,settlement_amount) ){
            uint256 amountToTransfer = settlement_amount - refTradeSpecs[trade_id].marginBuffer;
            _transfer(address_of_debitor, address(this), BUFFER, MARGIN, amountToTransfer); // autodebit
            _transfer(address(this), address_of_creditor, MARGIN, BUFFER, amountToTransfer); // autocredit
            emit SDCSettlementSuccessful(block.timestamp);
        }
        else{
            _performTermination();
            emit SDCTerminated(block.timestamp);
        }
        
        return true;
    }

    function _performTermination() private pure returns(bool){
        return true;
    }

    function _marginCheck() private pure returns(bool){

    }


    function _settlementCheck(string memory trade_id, uint256 amount) private view returns(bool){
        if ( refTradeSpecs[trade_id].marginBuffer <= amount) return true;
        else return false;
    }


    /*@notice Get the balance of an account's Tokens. */
    function balanceOf(address account, uint256 _id)  external view override returns (uint256){
        require(_id <= 4, "balanceOf: only four token types defined!");
        require(account != address(0x0), "balanceOf: balance query for the zero address");
        return balances[_id][account];
    }

    /*@notice Get the balance of multiple account/token pairs*/
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) external view override returns (uint256[] memory){
        require(accounts.length == ids.length, "balanceOfBatch: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = this.balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    /*  @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call). */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external override{
        _transfer(from,to,id,id,amount);
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    /* @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call). */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes memory data) external override{
        _batchTransfer(from,to,ids,ids,amounts);
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function mintBufferToken(address to, uint256 amount) external virtual onlyTokenManager {
        require(to != address(0), "mintBuffer: mint to the zero address");
        balances[BUFFER][to] += amount;
        emit TransferSingle(msg.sender, msg.sender, to, BUFFER, amount);
    }

    function burnBufferToken(address from, uint256 amount) external virtual onlyTokenManager {
        require(from != address(0), "burnBuffer: burn from the zero address");
        balances[BUFFER][from] -= amount;
        emit TransferSingle(msg.sender,from, msg.sender, BUFFER, amount);
    }
   

    /*@notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.*/
    function setApprovalForAll(address operator, bool isApproved) external override {
        require(operator != address(0x0), "setApprovalForAll: operator is zero address");
        address owner = msg.sender;
        operatorApprovals[owner][operator] = isApproved;
        emit ApprovalForAll(owner, operator, isApproved);
    }

    /*@notice Queries the approval status of an operator for a given owner.*/
    function isApprovedForAll(address owner, address operator) external view override returns (bool)  {
        require(owner != address(0x0), "isApprovedForAll: owner is zero address");
        require(operator != address(0x0), "isApprovedForAll: operator is zero address");
        return operatorApprovals[owner][operator];
    }

    function _transfer(address from, address to, uint256 id_from, uint256 id_to, uint256 amount) internal {
        require(to != address(0x0), "_transfer: transfer to the zero address");
        uint256 fromBalance = balances[id_from][from];
        require(fromBalance >= amount, "_transfer: insufficient balance for transfer");
        balances[id_from][from] = fromBalance - amount;
        balances[id_to][to] += amount;
    }

    
    function _batchTransfer(address from, address to, uint256[] memory ids_from, uint256[] memory ids_to, uint256[] memory amounts) internal {
        require(ids_from.length == amounts.length, "_batchCrossTransfer: ids and amounts length mismatch");
        require(ids_from.length == ids_to.length, "_batchCrossTransfer: ids_to and ids_from length mismatch");
        require(to != address(0), "safeBatchTransferFrom: transfer to the zero address");
        for (uint256 i = 0; i < ids_from.length; ++i) {
            uint256 id_from = ids_from[i];
            uint256 id_to = ids_from[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = balances[id_from][from];
            require(fromBalance >= amount, "_batchTransfer: insufficient balance for transfer");
            unchecked {
                balances[id_from][from] = fromBalance - amount;
            }
            balances[id_to][to] += amount;
        }

    }

    
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC1155).interfaceId;
    }



    
}
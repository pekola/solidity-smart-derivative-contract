// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/*  https://github.com/enjin/erc-1155/blob/master/contracts/IERC1155.sol
    https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol */

contract SDC1155 is IERC1155 {

    // const int ids for several token - i.e. account balance - types
    uint constant BUFFER            = 1;
    uint constant MARGIN            = 2;
    uint constant TERMINATIONFEE    = 3;
    uint constant VALUATIONFEE      = 4;

    enum TradeStatus{ INCEPTED, CONFIRMED, ACTIVE, TERMINATION_CONFIRMED, TERMINATED }

    string private sdc_id;
    // SDC need three addresses as token minting and burning is executed by a central authority
    address private counterparty1Address;
    address private counterparty2Address;
    address private tokenManagerAddress;

    // Specification of reference trades
    struct RefTradeSpec{
        uint256 trade_timestamp;
        string  fpml_data;
        address addressPayerSwap;       // Convention: PV calculation as seen from fixed rate payer = Fix - Float
        uint256 marginBuffer;           // Currently buffers and termination fee are assumed to be symmetric
        uint256 terminationFee;
        TradeStatus tradeStatus;
        address statusRequestAddress;   // this is the adress which has initiated a certain state change which needs to be confirmed - i.e. INCEPTION or TERMINATION
    }

    // Holds all reference trades
    mapping(string => RefTradeSpec) refTradeSpecs;

    // Holds all past valuations: timestamp -> map(trade_id,amount)
    uint256[] valuationTimeStamps;
    mapping(uint256 => mapping(string => uint256)) private pastSettlementAmounts;

    // Multi-Token Balance and operator approval map
    mapping(uint256 => mapping(address => uint256)) private balances;
    mapping(address => mapping(address => bool))    private operatorApprovals;

    // Trade Events
    event TradeIncepted(address fromAddress, string id, uint256 timestamp);
    event TradeConfirmed(address fromAddress, string id, uint256 timestamp);
    event TradeActive(string id, uint256 timestamp);
    event TradeTerminated(string id, address causingParty, uint256 timestamp);
    event TradeSettlementSuccessful(string id, uint256 timestamp);
    event ValuationRequest(uint256 timestamp);
    event TerminationRequested(address fromAddress, string trade_id, uint256 timestamp);
    event TerminationConfirmed(address fromAddress, string trade_id, uint256 timestamp);

    // Modifiers
    modifier onlyCounterparty { 
        require(msg.sender == counterparty1Address || msg.sender == counterparty2Address, "Not authorised"); _;
    }

    modifier onlyTokenManager {
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
    
    /*@notice: External Function to Incept a Trade with FPML data and margin and buffer amounts */
    function inceptTrade(string memory fpml_data, address fixPayerPartyAddress, uint256 terminationFee, uint256 marginBuffer) external onlyCounterparty returns(string memory){ 
        uint256 timestamp = block.timestamp;
        string memory trade_id = string(abi.encodePacked("trade_ref_",timestamp));
        refTradeSpecs[trade_id] = RefTradeSpec(timestamp,fpml_data,fixPayerPartyAddress,terminationFee,marginBuffer,TradeStatus.INCEPTED,msg.sender);
        emit TradeIncepted(msg.sender,trade_id,timestamp);
        return trade_id;
    }

    /*@notice: External Function to Confirm an incepted trade, triggers initial transfer of margin and termination fee */
    function confirmTrade(string memory trade_id) external onlyCounterparty  returns(bool){ 
        require(refTradeSpecs[trade_id].statusRequestAddress != msg.sender, "Trade-Inception cannot be confirmed by same address which has requested inception");
        refTradeSpecs[trade_id].trade_timestamp = block.timestamp;
        emit TradeConfirmed(msg.sender,trade_id,block.timestamp);
        _performTransfer(counterparty1Address, address(this), BUFFER, MARGIN, refTradeSpecs[trade_id].marginBuffer); 
        _performTransfer(counterparty1Address, address(this), BUFFER, TERMINATIONFEE, refTradeSpecs[trade_id].terminationFee); 
        _performTransfer(counterparty2Address, address(this), BUFFER, MARGIN, refTradeSpecs[trade_id].marginBuffer); 
        _performTransfer(counterparty2Address, address(this), BUFFER, TERMINATIONFEE, refTradeSpecs[trade_id].terminationFee); 
        refTradeSpecs[trade_id].tradeStatus = TradeStatus.ACTIVE;
        emit TradeActive(trade_id,block.timestamp);
        return true;
    }

    /*@notice: SDC - External Function to trigger a settlement with already know settlement amounts called by e.g. an external oracle service */
    function settle(string[] memory trade_ids, uint[] memory settlementAmounts ) public pure returns(bool){ 
        uint position;
        address creditor_address;
        for (uint i=0; i< trade_ids.length; i++){
            if (settlementAmounts[i] < 0 ){ // This case Payer Swap has decreased in value
                creditor_address = refTradeSpecs[trade_ids[0]].addressPayerSwap == counterparty1Address ? counterparty2Address : counterparty1Address;
                position =  -1;
            }
            else{
                creditor_address = refTradeSpecs[trade_ids[0]].addressPayerSwap;
                position = 1;
            }
            _performSettlementTransfer(trade_ids[i], position*settlementAmounts[i], creditor_address);
        }
        
        return true;
    }

    /*@notice: SDC - External Function to trigger a settlement for all active trades only triggered by a counterparty */
    function settle() external onlyCounterparty returns(bool){ 
        emit ValuationRequest(block.timestamp);
        //Wait as long as the block time is after the latest valuation timestamp i.e. a valuation has taken place
        while (block.timestamp < valuationTimeStamps[valuationTimeStamps.length-1]){
        }
        // uint256 latestTimeStamp = valuationTimeStamps[valuationTimeStamps.length-1];
        // call settle for 

        return true;
    }

    /*@notice: SDC - External function to request an early termination */
    function requestTradeTermination(string memory trade_id) external onlyCounterparty returns(bool){ 
        emit TerminationRequested(msg.sender,trade_id, block.timestamp);
        return true;
    }

    /*@notice: SDC - External function to confirm an early termination: Termination will be executed after next settlement */
    function confirmTradeTermination(string memory trade_id) external onlyCounterparty returns(bool){ 
        require(refTradeSpecs[trade_id].statusRequestAddress != msg.sender, "Trade-Termination cannot be confirmed by same address which has requested termination");
        emit TerminationConfirmed(msg.sender,trade_id, block.timestamp);
        refTradeSpecs[trade_id].tradeStatus = TradeStatus.TERMINATION_CONFIRMED;
        return true;
    }
    
     /*@notice: SDC - Communication with Oracle - External function to return fpml array  */
    function getRefTradeData() external pure  returns (string[] memory){
        string[] memory fpmlArray;
        return fpmlArray;
    }

    /*@notice: SDC - Communication with Oracle - External function to return fpml array  */
    function setSettlementAmounts(string[] calldata trade_ids, uint256[] calldata amounts, uint256 timestamp) external {
        for (uint i=0; i< trade_ids.length; i++)
            settlementAmounts[timestamp][trade_ids[i] ] = amounts[i];
        valuationTimeStamps.push(timestamp);
    }

     /*@notice: SDC - Internal function to perform a settlement transfer for specific trade id */
    function _performSettlementTransfer(string memory trade_id, uint256 settlement_amount, address address_of_creditor ) private returns(bool){
        require(settlement_amount > 0, "Settlement amount should be positive");
        require(address_of_creditor == counterparty1Address || address_of_creditor == counterparty2Address, "Creditor Address should be either CP1 oder CP");
        address address_of_debitor = address_of_creditor == counterparty1Address ? counterparty2Address : counterparty1Address;
        if ( _settlementCheck(trade_id,settlement_amount) ){
            uint256 amountToTransfer = settlement_amount - refTradeSpecs[trade_id].marginBuffer;
            if (_marginCheck(address_of_debitor, trade_id) ){
                _performTransfer(address_of_debitor, address(this), BUFFER, MARGIN, amountToTransfer); // autodebit
                _performTransfer(address(this), address_of_creditor, MARGIN, BUFFER, amountToTransfer); // autocredit
                emit TradeSettlementSuccessful(trade_id, block.timestamp);
                return true;
            }
        }
        _performTermination(trade_id);
        emit TradeTerminated(trade_id, address_of_debitor, block.timestamp);
        return false;
    }

    /*@notice: SDC - Internal function to perform termination */
    function _performTermination(string memory trade_id) private pure returns(bool){
        return true;
    }

    /*@notice: SDC - Check Margin */
    function _marginCheck(address cpAddress, string memory trade_id) private view returns(bool){
        if ( balances[BUFFER][cpAddress] >= refTradeSpecs[trade_id].marginBuffer )
            return true;
        else
            return false;
    }

    /*@notice: SDC - Check Settlement */
    function _settlementCheck(string memory trade_id, uint256 amount) private view returns(bool){
        if ( refTradeSpecs[trade_id].marginBuffer <= amount) return true;
        else return false;
    }

    /* @notice: SDC - Mints Buffer Token - Only be called from Token Manager - i.e. Kontoführer*/
    function mintBufferToken(address to, uint256 amount) external virtual onlyTokenManager {
        require(to != address(0), "mintBuffer: mint to the zero address");
        balances[BUFFER][to] += amount;
        emit TransferSingle(msg.sender, msg.sender, to, BUFFER, amount);
    }

    /* @notice: SDC - Burns Buffer Token - Only be called from Token Manager - i.e. Kontoführer*/
    function burnBufferToken(address from, uint256 amount) external virtual onlyTokenManager {
        require(from != address(0), "burnBuffer: burn from the zero address");
        balances[BUFFER][from] -= amount;
        emit TransferSingle(msg.sender,from, msg.sender, BUFFER, amount);
    }
   
    /*@notice: IERC1155 - Get the balance of an account's Tokens. */
    function balanceOf(address account, uint256 _id)  external view override returns (uint256){
        require(_id <= 4, "balanceOf: only four token types defined!");
        require(account != address(0x0), "balanceOf: balance query for the zero address");
        return balances[_id][account];
    }

    /*@notice: IERC1155 - Get the balance of multiple account/token pairs*/
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) external view override returns (uint256[] memory){
        require(accounts.length == ids.length, "balanceOfBatch: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = this.balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    /*  @notice: IERC1155 - Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call). */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external override{
        require(msg.sender==address(this),"Not authorised");  // cannot be called from other external address
        _performTransfer(from,to,id,id,amount);

    }

    /* @notice: IERC1155 - Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call). */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes memory data) external override{
        require(msg.sender==address(this),"Not authorised");  // cannot be called from other external address
        _performBatchTransfer(from,to,ids,ids,amounts);

    }

    
    /*@notice: IERC1155 - Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.*/
    function setApprovalForAll(address operator, bool isApproved) external override {
        require(operator != address(0x0), "setApprovalForAll: operator is zero address");
        address owner = msg.sender;
        operatorApprovals[owner][operator] = isApproved;
        emit ApprovalForAll(owner, operator, isApproved);
    }

    /*@notice: IERC1155 - Queries the approval status of an operator for a given owner.*/
    function isApprovedForAll(address owner, address operator) external view override returns (bool)  {
        require(owner != address(0x0), "isApprovedForAll: owner is zero address");
        require(operator != address(0x0), "isApprovedForAll: operator is zero address");
        return operatorApprovals[owner][operator];
    }

    /*@notice: Internal function to perform a cross token transfer */
    function _performTransfer(address from, address to, uint256 id_from, uint256 id_to, uint256 amount) internal {
        require(to != address(0x0), "_transfer: transfer to the zero address");
        uint256 fromBalance = balances[id_from][from];
        require(fromBalance >= amount, "_transfer: insufficient balance for transfer");
        balances[id_from][from] = fromBalance - amount;
        balances[id_to][to] += amount;
    }

    /*@notice: Internal function to perform a cross token batch transfer */
    function _performBatchTransfer(address from, address to, uint256[] memory ids_from, uint256[] memory ids_to, uint256[] memory amounts) internal {
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

    
    /*@notice: Some support interface implementation..to be explored further*/
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC1155).interfaceId;
    }



    
}
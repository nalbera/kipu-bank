// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract KipuBankV2 is Ownable, Pausable {

    //Contabilidad unificada
    //address(0) es la clave para Ether (ETH).
    mapping (address => mapping (address => uint256)) public userBalances;

    
    uint8 public constant USD_BASE_DECIMALS = 6;
    uint256 public immutable BANK_CAP_USD;
    uint256 public totalValueUSD = 0;
    
    //Mapea la dirección del activo a Chainlink Price Feed
    mapping (address => AggregatorV3Interface) internal tokenPriceFeeds;
    //Mapea la dirección del activo a los decimales de su Price Feed
    mapping (address => uint8) internal feedDecimals;
    //Mapea la dirección del activo a sus decimales nativos
    mapping (address => uint8) internal tokenDecimals;
    
    
    uint256 public immutable WITHDRAWAL_LIMIT;
    uint256 public totalDeposit;
    uint256 totalDeposits = 0;
    uint256 totalWithdrawals = 0;
    
    // Tokens ERC-20
    IERC20Metadata public immutable TOKEN_A;
    IERC20Metadata public immutable TOKEN_B;
    uint256 public immutable TOKEN_A_WITHDRAWAL_LIMIT;
    uint256 public immutable TOKEN_B_WITHDRAWAL_LIMIT;
    uint256 public immutable TOKEN_A_CAP;
    uint256 public immutable TOKEN_B_CAP;
    uint256 public totalTokenADeposit = 0;
    uint256 public totalTokenBDeposit = 0;

    // Contadores por usuario
    mapping (address => uint256) public ethDepositCount;
    mapping (address => uint256) public ethWithdrawCount;
    mapping (address => uint256) public tokenADepositCount;
    mapping (address => uint256) public tokenAWithdrawCount;
    mapping (address => uint256) public tokenBDepositCount;
    mapping (address => uint256) public tokenBWithdrawCount;

    event DepositSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance); 
    event WithdrawSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);
    event TokenADepositSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);
    event TokenAWithdrawSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);
    event TokenBDepositSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);
    event TokenBWithdrawSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);

    /**
    * @notice Inicializa el contrato con límites en USD y Data Feeds.
    */
    constructor(
        uint256 _withdrawalLimit,
        uint256 _bankCapUSD, // Límite en USD con USD_BASE_DECIMALS
        address _priceFeedETH,
        address _priceFeedTokenA,
        address _priceFeedTokenB,
        uint256 _tokenALimit,
        uint256 _tokenBLimit,
        uint256 _tokenACap,
        uint256 _tokenBCap
    ) Ownable(msg.sender) {
        WITHDRAWAL_LIMIT = _withdrawalLimit;
        BANK_CAP_USD = _bankCapUSD;
        
        _setTokenFeed(address(TOKEN_A), _priceFeedTokenA, TOKEN_A.decimals()); 
        _setTokenFeed(address(TOKEN_B), _priceFeedTokenB, TOKEN_B.decimals());
        
        TOKEN_A_WITHDRAWAL_LIMIT = _tokenALimit;
        TOKEN_B_WITHDRAWAL_LIMIT = _tokenBLimit;
        TOKEN_A_CAP = _tokenACap;
        TOKEN_B_CAP = _tokenBCap;

        _setTokenFeed(address(0), _priceFeedETH, 18);//18 decimales
        _setTokenFeed(address(TOKEN_A), _priceFeedTokenA, TOKEN_A.decimals());//Obtener decimales de Token A
        _setTokenFeed(address(TOKEN_B), _priceFeedTokenB, TOKEN_B.decimals());//Obtener decimales de Token B
    }

    
    /**
    * @notice Inicializa el feed, guarda decimales del feed y decimales nativos del token.
    */
    function _setTokenFeed(address _tokenAddress, address _feedAddress, uint8 _tokenDecimals) private {
        AggregatorV3Interface feed = AggregatorV3Interface(_feedAddress);
        tokenPriceFeeds[_tokenAddress] = feed;
        feedDecimals[_tokenAddress] = feed.decimals(); //Guarda los decimales del feed
        tokenDecimals[_tokenAddress] = _tokenDecimals; //Guarda los decimales nativos del token
    }

    /**
     * @notice Convierte una cantidad de cualquier token a su valor equivalente en USD 
     * usando la precisión USD_BASE_DECIMALS (6).
     */
    function _convertToUSD(address _tokenAddress, uint256 _amount) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[_tokenAddress];
        uint8 tDecimals = tokenDecimals[_tokenAddress];
        uint8 fDecimals = feedDecimals[_tokenAddress];
        
        //Obtener el precio actual
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Price feed returned non-positive price");
        
        uint256 uPrice = uint256(price);

         //formula para conversión a usd
        uint256 factor = 10**(uint256(tDecimals) + fDecimals);
        uint256 finalUSDValue = (_amount * uPrice * (10**uint256(USD_BASE_DECIMALS))) / factor;
        
        return finalUSDValue;
    }


    /**
    * @notice Permite al usuario depositar ETH en su bóveda personal.
    */
    function deposit() external payable whenNotPaused {

        require(msg.value > 0, "You must enter an amount");
        
        uint256 depositValueUSD = _convertToUSD(address(0), msg.value);
        require(totalValueUSD + depositValueUSD <= BANK_CAP_USD, "Deposit would exceed the bank's global USD limit");

        //Actualización de saldos y contadores
        userBalances[msg.sender][address(0)] += msg.value;
        ethDepositCount[msg.sender] ++;
        totalDeposit += msg.value;
        totalDeposits++;
        
        totalValueUSD += depositValueUSD;//Actualiza el valor total en USD

        emit DepositSuccessful(msg.sender, msg.value, userBalances[msg.sender][address(0)]);
    }

    /**
    * @notice Permite al usuario retirar ETHs de su bóveda.
    */
    function withdraw(uint256 _amount) external whenNotPaused {

        require(_amount > 0, "You must enter an amount");
        require(_amount <= WITHDRAWAL_LIMIT, "Withdrawal limit exceeded");
        require(_amount <= userBalances[msg.sender][address(0)], "Insufficient Balance");

        uint256 withdrawalValueUSD = _convertToUSD(address(0), _amount);
        totalValueUSD -= withdrawalValueUSD; 

        userBalances[msg.sender][address(0)] -= _amount;
        totalDeposit -= _amount;
        totalWithdrawals++;
        
        (bool success,) = msg.sender.call{value: _amount}("");

        require(success, "Failed to send ETH");

        ethWithdrawCount[msg.sender]++;

        emit WithdrawSuccessful(msg.sender, _amount, userBalances[msg.sender][address(0)]);
    }

    
    /**
    * @notice Permite al usuario depositar Token A en su bóveda.
    */
    function depositTokenA(uint256 _amount) external whenNotPaused {

        require(_amount > 0, "You must enter an amount");

        require(TOKEN_A.transferFrom(msg.sender, address(this), _amount), "Token A transfer failed");

        uint256 depositValueUSD = _convertToUSD(address(TOKEN_A), _amount);
        require(totalValueUSD + depositValueUSD <= BANK_CAP_USD, "Deposit would exceed the bank's global USD limit");

        userBalances[msg.sender][address(TOKEN_A)] += _amount;
        tokenADepositCount[msg.sender] ++;
        totalTokenADeposit += _amount;
        
        totalValueUSD += depositValueUSD;

        emit TokenADepositSuccessful(msg.sender, _amount, userBalances[msg.sender][address(TOKEN_A)]);
    }

    /**
    * @notice Permite al usuario retirar Token A de su bóveda.
    */
    function withdrawTokenA(uint256 _amount) external whenNotPaused {

        require(_amount > 0, "You must enter an amount");
        require(_amount <= TOKEN_A_WITHDRAWAL_LIMIT, "Token A withdrawal limit exceeded");
        require(_amount <= userBalances[msg.sender][address(TOKEN_A)], "Insufficient Token A Balance");

        uint256 withdrawalValueUSD = _convertToUSD(address(TOKEN_A), _amount);
        totalValueUSD -= withdrawalValueUSD;

        userBalances[msg.sender][address(TOKEN_A)] -= _amount;
        totalTokenADeposit -= _amount;

        require(TOKEN_A.transfer(msg.sender, _amount), "Failed to send Token A");

        tokenAWithdrawCount[msg.sender]++;

        emit TokenAWithdrawSuccessful(msg.sender, _amount, userBalances[msg.sender][address(TOKEN_A)]);
    }
    
    /**
    * @notice Permite al usuario depositar Token B en su bóveda.
    */
    function depositTokenB(uint256 _amount) external whenNotPaused {

        require(_amount > 0, "You must enter an amount");

        require(TOKEN_B.transferFrom(msg.sender, address(this), _amount), "Token B transfer failed");

        uint256 depositValueUSD = _convertToUSD(address(TOKEN_B), _amount);
        require(totalValueUSD + depositValueUSD <= BANK_CAP_USD, "Deposit would exceed the bank's global USD limit");

        userBalances[msg.sender][address(TOKEN_B)] += _amount;
        tokenBDepositCount[msg.sender] ++;
        totalTokenBDeposit += _amount;
        
        totalValueUSD += depositValueUSD;

        emit TokenBDepositSuccessful(msg.sender, _amount, userBalances[msg.sender][address(TOKEN_B)]);
    }

    /**
    * @notice Permite al usuario retirar Token B de su bóveda.
    */
    function withdrawTokenB(uint256 _amount) external whenNotPaused {

        require(_amount > 0, "You must enter an amount");
        require(_amount <= TOKEN_B_WITHDRAWAL_LIMIT, "Token B withdrawal limit exceeded");
        require(_amount <= userBalances[msg.sender][address(TOKEN_B)], "Insufficient Token B Balance");

        uint256 withdrawalValueUSD = _convertToUSD(address(TOKEN_B), _amount);
        totalValueUSD -= withdrawalValueUSD;

        userBalances[msg.sender][address(TOKEN_B)] -= _amount;
        totalTokenBDeposit -= _amount;

        require(TOKEN_B.transfer(msg.sender, _amount), "Failed to send Token B");

        tokenBWithdrawCount[msg.sender]++;

        emit TokenBWithdrawSuccessful(msg.sender, _amount, userBalances[msg.sender][address(TOKEN_B)]);
    }

    //Funciones de Pausa
    function pause() external onlyOwner {
         _pause();
    }

    function unpause() external onlyOwner { 
        _unpause();
    }

    /**
    * @notice Devuelve el saldo del usuario para un activo específico.
    */
    function getBalance(address _user, address _tokenAddress) public view returns (uint256) {
        return userBalances[_user][_tokenAddress];
    }
    
    /**
    * @notice Muestra el valor total de todos los depósitos en USD (con 6 decimales).
    */
    function getTotalValueInUSD() public view returns (uint256) {
        return totalValueUSD;
    }
    
    /**
    * @notice Devuelve el último precio conocido para un activo (con decimales del feed).
    */
    function getLatestPrice(address _tokenAddress) public view returns (int256) {
        (, int256 price, , , ) = tokenPriceFeeds[_tokenAddress].latestRoundData();
        return price;
    }

    
    function getWithdrawalLimit() public view returns (uint256) { 
        return WITHDRAWAL_LIMIT;
    }
    
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getContractTokenABalance() public view returns (uint256) { 
        return TOKEN_A.balanceOf(address(this));
    }

    function getContractTokenBBalance() public view returns (uint256) {
        return TOKEN_B.balanceOf(address(this));
    }

    function getCantTotalDeposit() public view returns (uint256){ 
        return totalDeposits;
    }

    function getCantTotalWithdrawals() public view returns (uint256){
        return totalWithdrawals;
    }
    
    function getRemainingDepositCapacity() public view returns (uint256){
        if(totalValueUSD >= BANK_CAP_USD){
            return 0;
        }
        return BANK_CAP_USD - totalValueUSD;
    }
    
    function ethToWei(uint256 _ethAmount) private pure returns (uint256) {
        return _ethAmount * 10**18;
    }
}
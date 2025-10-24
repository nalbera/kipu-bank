// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

contract KipuBank {

    //Bóveda personal
    mapping (address => uint256) public ethBalances;

    //Contadores por usuario
    mapping (address => uint256) public ethDepositCount;
    mapping (address => uint256) public ethWithdrawCount;

    //Contadores generales
    uint256 totalDeposits = 0;
    uint256 totalWithdrawals = 0;

    //Limite de retiro por transacción
    uint256 public immutable WITHDRAWAL_LIMIT;

    //Limite global de depósito
    uint256 public immutable BANK_CAP;

    //controla el total de depósitos independientemente del saldo del contract
    uint256 public totalDeposit;

    event DepositSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);
    event WithdrawSuccessful(address indexed user, uint256 amount, uint256 newTotalBalance);

    /**
    * @notice Inicializa el contrato estableciendo los límites de seguridad.
    * @param _withdrawalLimit Límite máximo de ETH (en wei) por retiro.
    * @param _bankCap Límite total de ETH (en wei) que el contrato puede contener.
    */
    constructor(uint256 _withdrawalLimit, uint256 _bankCap) {
        WITHDRAWAL_LIMIT = _withdrawalLimit;
        BANK_CAP = _bankCap;
    }


    /**
    * @notice Permite al usuario depositar ETH en su bóveda personal.
    * @dev Función 'external' y 'payable'.
    */
    function deposit() external payable {

        require(msg.value > 0, "You must enter an amount");

        require(totalDeposit + msg.value <= BANK_CAP, "Deposit Limit Exceeded");

        ethBalances[msg.sender] += msg.value;

        ethDepositCount[msg.sender] ++;

        totalDeposit += msg.value;

        totalDeposits++;

        emit DepositSuccessful(msg.sender, msg.value, ethBalances[msg.sender]);
    }

    /**
    * @notice Permite al usuario retirar ETHs de su bóveda.
    * @param _amount La cantidad de ETH (en wei) a retirar.
    * @dev Es una función 'external'.
    */
    function withdraw(uint256 _amount) external {

        require(_amount > 0, "You must enter an amount");

        require(_amount <= WITHDRAWAL_LIMIT, "Not enough ETH in your vault");

        require(_amount <= ethBalances[msg.sender], "Insufficient Balance");

        ethBalances[msg.sender] -= _amount;

        totalDeposit -= _amount;

        totalWithdrawals++;
        
        (bool success,) = msg.sender.call{value: _amount}("");

        require(success, "Failed to send ETH");

        ethWithdrawCount[msg.sender]++;

        emit WithdrawSuccessful(msg.sender, _amount, ethBalances[msg.sender]);
    }

    /**
    * @notice Devuelve el saldo del usuario.
    * @param _user La dirección del usuario.
    * @return El saldo total de ETH (en wei).
    */
    function getBalance(address _user) public view returns (uint256) {
        return ethBalances[_user];
    }

    /**
    * @notice Devuelve el límite de retiro por transacción.
    * @dev Es una función de vista para el valor inmutable.
    * @return El límite de retiro (en wei).
    */
    function getWithdrawalLimit() public view returns (uint256) {
        return WITHDRAWAL_LIMIT;
    }

    /**
    * @notice Muestra el balance total de ETH del contrato (balance global).
    * @dev Usa la sintaxis de Solidity para acceder al balance del contrato.
    * @return El balance total del contrato (en wei).
    */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
    * @notice Muestra equivalencias entre wei y eth
    * @dev Función auxiliar
    * @return Valor convertido
    */
    function ethToWei(uint256 _ethAmount) private pure returns (uint256) {
        return _ethAmount * 10**18; //10 a la 18
    }

    /**
    * @notice Muestra cuanto puede depositar sin exceder el límite
    * @dev Función auxiliar
    * @return Espacio que le queda al contraro (en wei)
    */
    function getRemainingDepositCapacity() public view returns (uint256){
        if(address(this).balance >= BANK_CAP){
            return 0;
        }
        return BANK_CAP - address(this).balance;
    }

    /**
    * @notice Muestra la cantidad total de depósitos que se hicieron
    * @dev Función auxiliar
    * @return Retorna un número que representa la cantidad total de depósitos
    */
    function getCantTotalDeposit() public view returns (uint256){
        return totalDeposits;
    }

    /**
    * @notice Muestra la cantidad total de extracciones  que se hicieron
    * @dev Función auxiliar
    * @return Retorna un número que representa la cantidad total de extracciones
    */
    function getCantTotalWithdrawals() public view returns (uint256){
        return totalWithdrawals;
    }

}
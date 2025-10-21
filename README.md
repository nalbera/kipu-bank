# 🏦 KipuBank

**KipuBank** es un contrato inteligente escrito en Solidity que permite a los usuarios depositar y retirar ETH en una bóveda personal, con límites de seguridad configurables. Ideal para aprender sobre gestión de fondos, límites de retiro, y control de capacidad en contratos descentralizados.

---

## 📦 Características principales

- 🧾 Bóveda personal por dirección (`mapping`)
- 📈 Contadores de depósitos y retiros individuales
- 🔒 Límite de retiro por transacción (`WITHDRAWAL_LIMIT`)
- 🏛️ Límite global de depósitos (`BANK_CAP`)
- 📊 Control interno de depósitos acumulados (`totalDeposit`)
- 📤 Funciones auxiliares para conversión y capacidad restante

---

## 🚀 Instalación y despliegue

1. Cloná el repositorio:
   ```bash
   git clone https://github.com/tuusuario/kipubank.git
   cd kipubank
   ```

2. Compilá el contrato con Hardhat o Remix
   ```bash
   npx hardhat compile
   ```

3. Desplegá en eun red local o testnet
   ```js
   const KipuBank = await ethers.getContractFactory("KipuBank");
   const bank = await KipuBank.deploy(
    ethers.utils.parseEther("1"),  // Límite de retiro: 1 ETH
    ethers.utils.parseEther("30") // Capacidad total: 30 ETH
   );
   ```
---

## 🧪 Uso del contrato

### 📥 Depositar ETH
<ul>
    <li>Requiere que el valor sea mayor a 0 "cero"</li>
    <li>Verifica que el depósito no exceda el BANK_CAP</li>
    <li>Actualiza el saldo personal y contador de depósitos</li>
</ul>

### 📥 Retirar ETH
<ul>
    <li>Verifica que el monto sea mayor a 0 "cero"</li>
    <li>Verifica que no exceda el límite de retiro ni el saldo personal</li>
    <li>Envía ETH al usuario y actualiza el contador de retiro</li>
</ul>

## 🔍 Funciones públicas

| Función                          | Descripción                                                  | Tipo     |
|----------------------------------|--------------------------------------------------------------|----------|
| `getBalance(address)`            | Devuelve el saldo en wei del usuario                         | `view`   |
| `getWithdrawalLimit()`           | Devuelve el límite de retiro por transacción                 | `view`   |
| `getContractBalance()`           | Devuelve el balance total del contrato                       | `view`   |
| `ethToWei(uint256)`              | Convierte ETH a wei                                          | `pure`   |
| `getRemainingDepositCapacity()`  | Muestra cuánto se puede depositar sin exceder el límite      | `view`   |


## ⚠ Consideraciones de segurirdad

- El contrato usa `call` para enviar ETH, lo que es seguro si se maneja correctamente.
- Los límietes de retiro y depósito protegen contra abusos y sobre carga del contrato.
- `totalDeposit` se usa para controlar depósitos válidos, evitando depender del balance del contrato que puede incluír ETH enviado por error.

## 📚 Licencia
Este proyecto está bajo la licencia <strong>GPL-3.0</strong>

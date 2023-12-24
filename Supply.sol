pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

contract User {
    string name;
    uint balance;

    event UserRegistered(string userName, uint initialBalance);

    // 构造函数，注册用户
    constructor(string memory _name, uint _balance) public {
        name = _name;
        balance = _balance;

        // 触发用户装注册事件
        emit UserRegistered(_name, _balance);
    }

    // 获取用户名称
    function getName() public view returns (string memory) {
        return name;
    }

    function getBalance() public view returns (uint) {
        return balance;
    }
}

contract RawMaterialSupplier is User {
    uint price;
    uint amount;

    // 构造函数，注册原材料
    constructor(
        string memory _name,
        uint _price,
        uint _amount,
        uint _balance
    ) public User(_name, _balance) {
        price = _price;
        amount = _amount;
    }

    // 事件：购买原材料
    event RawMaterialPurchased(
        string materialName,
        uint amount,
        uint totalPrice
    );

    function getPrice() public view returns (uint) {
        return price;
    }

    // 获取原材料信息
    function getRawMaterial() public view returns (string memory, uint, uint) {
        return (name, price, amount);
    }

    // 修饰符：限制原材料数量
    modifier requireSufficientAmount(uint _amount) {
        require(amount >= _amount, "Insufficient amount");
        _;
    }

    // 修饰符：要求输入金额大于原材料价格*数量
    modifier requireSufficientMoney(uint _amount, uint _money) {
        require(_money >= price * _amount, "Not enough money");
        _;
    }

    // 购买函数，其他用户通过购买函数购买原材料
    function buyRawMaterial(
        uint _amount,
        uint money
    )
        public
        requireSufficientAmount(_amount)
        requireSufficientMoney(_amount, money)
    {
        // 转账给供应商
        balance += money;
        // 原材料数量减少
        amount -= _amount;

        // 触发购买原材料事件
        emit RawMaterialPurchased(name, _amount, money);
    }
}

contract Producers is User {
    address productAddress;

    // 构造函数，注册生产者
    constructor(
        string memory _name,
        address _address,
        uint _balance
    ) public User(_name, _balance) {
        productAddress = _address;
        
    }

    // 事件：产品创建完成
    event ProductCreated(string productName, uint price);

    mapping(string => address) rawMaterialSuppliers;

    // 映射原材料所需个数
    mapping(string => uint) rawMaterials;
    string[] rawMaterialsName;
    uint rawMaterialsCount;

    // 获取所有原材料名称
    function getRawMaterialsName() public view returns (string[] memory) {
        return rawMaterialsName;
    }

    // 用户输入原材料名称和所需个数，添加到映射中
    function addRawMaterial(string memory _name, uint _amount) public {
        rawMaterials[_name] = _amount;
        rawMaterialsName.push(_name);
        rawMaterialsCount++;
    }

    // 用户输入原材料名称和供应商地址，添加到映射中
    function addRawMaterialSupplier(
        string memory _name,
        address _supplierAddress
    ) public {
        rawMaterialSuppliers[_name] = _supplierAddress;
    }

    // 修饰符：要求原材料已经被添加到映射中
    modifier requireRawMaterialAdded(string memory _materialName) {
        require(rawMaterials[_materialName] > 0, "Raw material not added");
        _;
    }

    // 修饰符：要求产品状态必须为原材料状态
    modifier requireRawMaterialState() {
        Product product = Product(productAddress);
        require(
            keccak256(abi.encodePacked(product.getState())) ==
                keccak256(abi.encodePacked("RawMaterial")),
            "Product not in raw material state"
        );
        _;
    }

    // 修饰符：生产之前，检查用户余额是否足够
    modifier requireSufficientBalance(uint _price) {
        require(balance >= _price, "Insufficient balance");
        _;
    }

    // 获取总原材料成本
    function getTotalPrice() public view returns (uint) {
        uint totalPrice = 0;
        for (uint i = 0; i < rawMaterialsCount; i++) {
            totalPrice +=
                rawMaterials[rawMaterialsName[i]] *
                RawMaterialSupplier(rawMaterialSuppliers[rawMaterialsName[i]])
                    .getPrice();
        }
        return totalPrice;
    }

    // 调用原材料合约，购买原材料
    function purchaseRawMaterial(
        string memory _materialName
    ) private requireRawMaterialAdded(_materialName) {
        RawMaterialSupplier rawMaterialSupplier = RawMaterialSupplier(
            rawMaterialSuppliers[_materialName]
        );

        uint money = rawMaterials[_materialName] *
            rawMaterialSupplier.getPrice();
        rawMaterialSupplier.buyRawMaterial(rawMaterials[_materialName], money);
        balance -= money;
    }

    // 生产函数，用户调用改函数，生产产品，并将产品转交给用户
    function produce()
        public
        requireRawMaterialState
        requireSufficientBalance(getTotalPrice())
    {
        // 调用原材料合约，购买原材料
        for (uint i = 0; i < rawMaterialsCount; i++) {
            purchaseRawMaterial(rawMaterialsName[i]);
        }
        // 生产产品
        setProduce();

        // 触发产品创建完成事件
        emit ProductCreated(name, getTotalPrice());
    }

    function setProduce() private {
        Product product = Product(productAddress);
        product.setState(1);
    }
}

contract Warehouse is User {
    uint amount;
    uint price;
    address productAddress;

    // 构造函数，注册仓库
    constructor(
        string memory _name,
        uint _balance,
        address _address
    ) public User(_name, _balance) {
        productAddress = _address;
    }

    // 修饰符：检查余额是否足够
    modifier requireSufficientBalance() {
        require(balance >= price, "Insufficient balance");
        _;
    }

    // 修饰符：在转移之前检查数量是否足够
    modifier requireSufficientAmount() {
        require(amount > 0, "Insufficient amount");
        _;
    }

    event ProductPurchased(address warehouseAddress, uint totalPrice);

    // 外部用户调用，购买产品
    function buyProduct(uint _money) public {
        require(amount > 0, "Insufficient amount");
        balance += _money;
        amount--;
        setWarehouse();

        // 触发产品购买事件
        emit ProductPurchased(address(this), _money);
    }

    // 调用生产者合约，生成产品
    function produceProduct(address _address) public requireSufficientBalance {
        Producers producer = Producers(_address);
        producer.produce();
        amount++;
        balance -= price;
    }

    // 设置产品状态
    function setWarehouse() private {
        Product product = Product(productAddress);
        product.setState(2);
    }
}

contract Product {
    string name;
    uint price;
    enum State {
        RawMaterial,
        Producer,
        Warehouse,
        Customer
    }
    State state;

    // 添加公钥
    bytes32 public publicKey;

    // 构造函数，注册产品
    constructor(string memory _name, uint _price, bytes32 _publicKey) public {
        name = _name;
        price = _price;
        state = State.RawMaterial;
        publicKey = _publicKey;
    }

    function getPrice() public view returns (uint) {
        return price;
    }

    // 查看产品状态
    function getState() public view returns (string memory) {
        if (state == State.RawMaterial) {
            return "RawMaterial";
        } else if (state == State.Producer) {
            return "Producer";
        } else if (state == State.Warehouse) {
            return "Warehouse";
        } else if (state == State.Customer) {
            return "Customer";
        }
    }

    // 在合约外部修改产品状态
    function setState(uint _state) public {
        if (_state == 0) {
            state = State.RawMaterial;
        } else if (_state == 1) {
            state = State.Producer;
        } else if (_state == 2) {
            state = State.Warehouse;
        } else if (_state == 3) {
            state = State.Customer;
        }
    }
}

contract Consumer {
    string name;
    address user;
    uint amount;
    uint balance;

    // 事件：用户购买商品
    event ProductPurchased(address consumerAddress, uint totalPrice);

    // 构造函数，注册用户
    constructor(string memory _name, uint _balance) public {
        name = _name;
        balance = _balance;
    }

    // 购买函数，用户调用函数，购买产品
    function buyProduct(
        address _WarehouseAddress,
        address _productAddress,
        uint _money
    ) public {
        Product product = Product(_productAddress);
        uint price = product.getPrice();
        require(balance >= price, "Insufficient balance");
        Warehouse warehouse = Warehouse(_WarehouseAddress);
        warehouse.buyProduct(_money);
        amount++;
        balance -= _money;

        emit ProductPurchased(address(this), _money);
    }

    function setConsumer(address _address) public {
        Product product = Product(_address);
        product.setState(3);
    }

    function getState(address _address) public view returns (string memory) {
        Product product = Product(_address);
        return product.getState();
    }
}

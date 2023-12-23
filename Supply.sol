pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

contract User {
    string name;
    uint256 balance;

    // 构造函数，注册用户
    constructor(string memory _name, uint256 _balance) public {
        name = _name;
        balance = _balance;
    }

    // 获取用户名称
    function getName() public view returns (string memory) {
        return name;
    }

    // 获取用户余额
    function getBalance() public view returns (uint256) {
        return balance;
    }
}

contract RawMaterialSupplier is User {
    uint256 price;
    uint256 amount;

    // 构造函数，注册原材料
    constructor(
        string memory _name,
        uint256 _price,
        uint256 _amount,
        uint256 _balance
    ) public User(_name, _balance) {
        price = _price;
        amount = _amount;
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    // 获取原材料信息
    function getRawMaterial()
        public
        view
        returns (string memory, uint256, uint256)
    {
        return (name, price, amount);
    }

    // 购买函数，其他用户通过购买函数购买原材料
    function buyRawMaterial(uint256 _amount, uint256 money) public {
        // 判断用户是否有足够的钱购买原材料
        require(money >= price * _amount, "Not enough money");
        // 转账给供应商
        balance += money;
        // 原材料数量减少
        amount -= _amount;
    }
}

contract Producers is User {
    address productAddress;

    // 构造函数，注册生产者
    constructor(
        string memory _name,
        address _address,
        uint256 _balance
    ) public User(_name, _balance) {
        productAddress = _address;
    }

    mapping(string => address) rawMaterialSuppliers;

    // 映射原材料所需个数
    mapping(string => uint256) rawMaterials;
    string[] rawMaterialsName;
    uint256 rawMaterialsCount;

    // 获取所有原材料名称
    function getRawMaterialsName() public view returns (string[] memory) {
        return rawMaterialsName;
    }

    // 用户输入原材料名称和所需个数，添加到映射中
    function addRawMaterial(string memory _name, uint256 _amount) public {
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

    // 调用原材料合约，购买原材料
    function purchaseRawMaterial(string memory _materialName) private {
        RawMaterialSupplier rawMaterialSupplier = RawMaterialSupplier(
            rawMaterialSuppliers[_materialName]
        );

        rawMaterialSupplier.buyRawMaterial(
            rawMaterials[_materialName],
            rawMaterials[_materialName] * rawMaterialSupplier.getPrice()
        );
    }

    // 生产函数，用户调用改函数，生产产品，并将产品转交给用户
    function produce() public {
        // 调用原材料合约，购买原材料
        for (uint256 i = 0; i < rawMaterialsCount; i++) {
            purchaseRawMaterial(rawMaterialsName[i]);
        }
        // 生产产品
        setProduce();
    }

    function setProduce() public {
        Product product = Product(productAddress);
        product.setState(1);
    }
}

contract Warehouse is User {
    uint256 amount;
    uint256 price;
    address productAddress;
    uint256 timestamp;

    // 构造函数，注册仓库
    constructor(
        string memory _name,
        uint256 _balance,
        address _address
    ) public User(_name, _balance) {
        productAddress = _address;
    }

    // 用户购买商品
    function buyProduct(uint256 money) public {
        require(money == price, "Not enough money");
        balance += money;
        amount--;
    }

    // 调用生产者合约，生成产品
    function produceProduct(address _address) public {
        Producers producer = Producers(_address);
        producer.produce();
        amount++;
    }

    // 设置产品状态
    function setWarehouse() private {
        Product product = Product(productAddress);
        product.setState(2);
    }
}

contract Product {
    string name;
    uint256 price;
    enum State {
        RawMaterial,
        Producer,
        Warehouse,
        Customer
    }
    State state;

    // 构造函数，注册产品
    constructor(string memory _name, uint256 _price) public {
        name = _name;
        price = _price;
        state = State.RawMaterial;
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
    function setState(uint256 _state) public {
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
    uint256 amount;
    uint256 balance;

    // 构造函数，注册用户
    constructor(string memory _name, uint256 _balance) public {
        name = _name;
        balance = _balance;
    }

    // 购买函数，用户调用改函数，购买产品
    function buyProduct(address _address, uint256 money) public {
        Warehouse warehouse = Warehouse(_address);
        warehouse.buyProduct(money);
        amount++;
        balance -= money;
    }

    function setConsumer(address _address) private {
        Product product = Product(_address);
        product.setState(3);
    }

    function getState(address _address) public view returns (string memory) {
        Product product = Product(_address);
        return product.getState();
    }
}

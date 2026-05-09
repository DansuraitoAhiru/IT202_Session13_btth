USE RikkeiClinicDB;

CREATE TABLE Services (
    service_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(18,2) NOT NULL
);

CREATE TABLE Wallets (
    patient_id INT PRIMARY KEY,
    balance DECIMAL(18,2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'Active', -- 'Active', 'Inactive'
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
);

CREATE TABLE Service_Usages (
    usage_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    service_id INT NOT NULL,
    actual_price DECIMAL(18,2) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (service_id) REFERENCES Services(service_id)
);

INSERT INTO Services (service_id, name, price) 
VALUES
	(1, 'Sieu am o bung', 200000.00),
	(2, 'Xet nghiem mau', 150000.00),
	(3, 'Chup X-Quang', 250000.00);

-- Chèn Ví điện tử
INSERT INTO Wallets (patient_id, balance, status) 
VALUES
	(1, 500000.00, 'Active'),    -- Test Case 1: Đủ tiền thanh toán
	(2, 50000.00, 'Active'),     -- Test Case 3: Cháy ví (Chỉ có 50k, không đủ khám 200k)
	(3, 1000000.00, 'Inactive'); -- Test Case 2: Nhiều tiền nhưng thẻ bị khóa

-- Phần A:
-- Xác định thời điểm kích hoạt và sự kiện: sẽ là BEFORE INSERT vào bảng Service_Usages
-- vì trigger bắt phải gán price từ Services vào actual_price, nếu dùng after thì sẽ bị lỗi do cơ chế mặc định ko cho trigger sửa khi insert
-- và đề bài thì chỉ yêu cầu xây dựng 1 trigger nên bắt buộc phải chọn BEFORE INSERT

-- Biến cục bộ cần dùng:
-- v_actual_price là biến lưu giá trị của price(giá dịch vụ) từ bảng Services
-- v_status là biến lưu giá trị của status(trạng thái ví) từ bảng Wallets
-- v_balance là biến lưu giá trị của balance(số dư ví) từ bảng Wallets

-- Phần B: code
delimiter //
create trigger tg_insert_actual_usage
before insert on Service_Usages
for each row
begin
	declare v_actual_price decimal(18, 2);
    declare v_status VARCHAR(20);
    declare v_balance DECIMAL(18,2);
    
	select price into v_actual_price from Services
    where service_id = New.service_id;
	set New.actual_price = v_actual_price;
    
    select status, balance into v_status, v_balance from Wallets
    where patient_id = New.patient_id;
    
    if v_status = 'INACTIVE' then
		signal sqlstate '45000'
        set message_text = 'Thất bại: Ví trả trước đang bị khóa';
	elseif v_balance < v_actual_price then
		signal sqlstate '45000'
        set message_text = 'Thất bại: Số dư ví không đủ để thanh toán';
	else 
		update Wallets
        set balance = balance - v_actual_price
        where patient_id = New.patient_id;
	end if;
end //
delimiter ;

-- test
-- giao dịch hợp lệ
insert into Service_Usages(patient_id, service_id)
values (1, 2);
select * from Service_Usages;

-- thẻ bị khóa
insert into Service_Usages(patient_id, service_id)
values (3, 3);

-- cháy ví, có số dư 50k, đòi khám dịch vụ 200k)
insert into Service_Usages(patient_id, service_id)
values (2, 1);

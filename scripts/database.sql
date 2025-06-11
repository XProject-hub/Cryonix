CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role ENUM('admin', 'reseller', 'user') DEFAULT 'user',
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    stream_url TEXT NOT NULL,
    type ENUM('live', 'vod') DEFAULT 'live',
    category_id INT,
    status BOOLEAN DEFAULT 1,
    quality VARCHAR(10) DEFAULT '720p',
    viewers INT DEFAULT 0,
    epg_id VARCHAR(100),
    auto_restart BOOLEAN DEFAULT 1,
    last_started TIMESTAMP NULL,
    last_stopped TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE IF NOT EXISTS stream_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel_id INT,
    action ENUM('start', 'stop', 'restart', 'error'),
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_id) REFERENCES channels(id)
);

-- Insert default data
INSERT INTO users (username, password, role) VALUES 
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin');

INSERT INTO categories (name, description) VALUES 
('Sports', 'Sports channels'),
('Movies', 'Movie channels'),
('News', 'News channels'),
('Entertainment', 'Entertainment channels');

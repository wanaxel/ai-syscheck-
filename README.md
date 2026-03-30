# ai-syscheck
a program i created for fun, it use ollama and detect ur system to use the best mode, its job is to detect any anomalies error and give recommendation to optimize your linux system (this is for fun im not planning to continue this at all)

---

## Features
Detect anomalies <br> 
Give recommendation to optimize and fix <br> 
Can be use in tty in case you break your system <br> 

--- 

## Setup Instructions 
### 1. Install [Ollama](https://ollama.com)
Ollama is required 

#### 
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### 2. Clone and run the app 
```bash
https://github.com/wanaxel/ai-syscheck-.git
cd ai-syscheck-
chmod +x ai-syscheck.sh
sudo ./ai-syscheck.sh
```

| System Info | Storage Analyze | Kernel Analyze |
|:-:|:-:|:-:|
| ![](https://github.com/user-attachments/assets/33da699c-af84-4fc5-afd7-bb16a77d1504) | ![](https://github.com/user-attachments/assets/591810f1-f373-4c22-a71a-21bc85e713ce) | ![](https://github.com/user-attachments/assets/192ab5e7-805c-4fad-b20e-06dc298e1c82) |

| Bootloader Analyze | Compositor/Gpu Analyze | Package Cache Analyze & End result |
|:-:|:-:|:-:|
| ![](https://github.com/user-attachments/assets/56b7be01-f6fb-45a6-8986-9bfb2e1a029c) | ![](https://github.com/user-attachments/assets/1c4a2eb7-7029-4729-a352-5903737b75dd) | ![](https://github.com/user-attachments/assets/4af3e876-9817-4973-bb8c-5047838c2431) |

---

## ⚠️ Disclaimer

This tool is experimental and created for fun.  
Use at your own risk, especially when running with `sudo`.

---

##  Contributing

Not actively maintained, but feel free to fork and experiment with it.

---

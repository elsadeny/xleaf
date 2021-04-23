import NetworkExtension

let appGroup = "group.com.macos.xleaf"

// See https://github.com/eycorsican/leaf/blob/master/README.zh.md#conf for more conf examples.
let conf = """
[General]
loglevel = trace
dns-server = 223.5.5.5, 114.114.114.114
tun-fd = REPLACE-ME-WITH-THE-FD
routing-domain-resolve = true

[Proxy]
Direct = direct
Proxy = trojan, 1.2.3.4, 443, password=123456, sni=server.com

[Rule]
EXTERNAL, site:cn, Direct
EXTERNAL, mmdb:cn, Direct
FINAL, Proxy
"""

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let tunnelNetworkSettings = createTunnelSettings()
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            let tunFd = self?.packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
            let confWithFd = conf.replacingOccurrences(of: "REPLACE-ME-WITH-THE-FD", with: String(tunFd))
            let url = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroup)!.appendingPathComponent("running_config.conf")
            do {
                try confWithFd.write(to: url, atomically: false, encoding: .utf8)
            } catch {
                NSLog("fialed to write config file \(error)")
            }
            setenv("ASSET_LOCATION", Bundle.main.resourcePath, 1)
            setenv("LOG_NO_COLOR", "true", 1)
            setenv("LOG_CONSOLE_OUT", "true", 1)
            DispatchQueue.global(qos: .userInteractive).async {
                signal(SIGPIPE, SIG_IGN)
                leaf_run(0, url.path)
            }
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    func createTunnelSettings() -> NEPacketTunnelNetworkSettings  {
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.10")
        newSettings.ipv4Settings = NEIPv4Settings(addresses: ["240.0.0.1"], subnetMasks: ["255.255.255.0"])
        newSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.`default`()]
        newSettings.proxySettings = nil
        newSettings.dnsSettings = NEDNSSettings(servers: ["223.5.5.5", "8.8.8.8"])
        newSettings.mtu = 1500
        return newSettings
    }
}

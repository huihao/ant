local pkg = {}
for _, name in ipairs {
    "addressnavigation_ctrl",
    "assetprobe",
    "hierarchyview",
    "listctrl",
    "matrixview",
    "popupmenu",
    "propertyview",
    "tree",
    "vectorview",
    "icon",
    "util",
} do
    pkg[name] =     require(name)
end

pkg["logview"] =    require "log.logview"
pkg.common = {
    observer =      require "common.observer",
    hub =           require "common.hub",
}
return pkg
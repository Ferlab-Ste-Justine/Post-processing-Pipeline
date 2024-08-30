def isVepToolIncluded() {
    return isToolIncluded("vep")
}

def isExomiserToolIncluded() {
    return isToolIncluded("exomiser")
}

def isToolIncluded(tool) {
    return params.tools && params.tools.split(",").contains(tool)
}
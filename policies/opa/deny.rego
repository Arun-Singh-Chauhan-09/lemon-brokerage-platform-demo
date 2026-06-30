package main

# Compliance-as-code: reject manifests that violate baseline controls a
# regulated broker would require. Run with: conftest test gitops/ -p policies/opa

# 1. No container may run as root.
deny[msg] {
    input.kind == "Deployment"
    c := input.spec.template.spec.containers[_]
    not c.securityContext.runAsNonRoot
    msg := sprintf("container '%s' must set securityContext.runAsNonRoot=true", [c.name])
}

# 2. No floating image tags — auditability requires pinned images.
deny[msg] {
    input.kind == "Deployment"
    c := input.spec.template.spec.containers[_]
    endswith(c.image, ":latest")
    msg := sprintf("container '%s' must not use the ':latest' tag", [c.name])
}

# 3. Every container must declare resource limits (cost + stability control).
deny[msg] {
    input.kind == "Deployment"
    c := input.spec.template.spec.containers[_]
    not c.resources.limits
    msg := sprintf("container '%s' must declare resources.limits", [c.name])
}

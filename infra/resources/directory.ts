import * as azuread from "@pulumi/azuread"

export const tenantId = "2be5c49d-d8ac-4700-a8a7-10668c406a70";
export const me = azuread.getUser({
    objectId: "e48d9318-160b-4abc-99ef-b561a9d8d9c0"
})
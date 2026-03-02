Fix authentik 2026.2.0 startup crash caused by Django migration ordering bug (`FieldError: Cannot resolve keyword 'group_id'`). Patch ensures `authentik_core/0056` runs before `authentik_rbac/0010`.

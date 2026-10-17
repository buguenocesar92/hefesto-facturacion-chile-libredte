# 04 — Primera cuenta, usuarios y permisos

Lo que realmente hace la aplicación, verificado leyendo el código del tag
`v0.1.0b1` de `libredte-app-slim`.

---

## 1. La primera cuenta se crea sola al primer visitante

No hay que ejecutar ningún comando para el primer usuario. Mientras la tabla de
usuarios esté vacía, el middleware `RequireInitialUserMiddleware`
(`apps/core/middleware.py`) **redirige todas las peticiones a `/setup/`**, salvo
`/health/` y las vistas exentas.

Consecuencias prácticas:

- Cualquiera que abra `https://tu-dominio/` **antes** de que se cree el usuario
  puede crearlo. No hay clave de instalación.
- `/setup/` crea el usuario con `UserCreationForm` y, además, lo guarda con
  `is_staff=True` e `is_superuser=True`: **el primer usuario es
  administrador**.
- Apenas existe un usuario, `setup()` redirige a la portada y **deja de servir
  el alta**. La pantalla se cierra sola; no hay que "desactivar el registro".

### Orden recomendado en el día del despliegue

1. Levantar el stack.
2. **Inmediatamente** abrir `https://tu-dominio/setup/` y crear el primer usuario.
3. Verificar que entrar a `/setup/` de nuevo ya no ofrece el formulario.

Si el servidor estuvo expuesto a internet más rato del previsto antes de crear el
usuario, hay que asumir que alguien pudo crearlo. Revisar con la consola de
Slim:

```shell
docker compose run --rm console shell
>>> from django.contrib.auth.models import User
>>> User.objects.values_list('username', 'is_superuser', 'date_joined')
```

Si hay un usuario desconocido: **no lo borres a ciegas**, puede tener datos
asociados. Cambiale la contraseña y dejalo sin permisos:

```shell
docker compose run --rm console changepassword usuario-sospechoso
```

## 2. Crear usuarios después

Desde la aplicación web, en Configuración. Cada usuario es una cuenta
independiente.

Para cambiar una contraseña por consola:

```shell
docker compose run --rm console changepassword nombre-usuario
```

Con `console` los archivos quedan a nombre del usuario `slim` de la imagen.

## 3. Dos factores

El login usa `LoginForm` (`apps/core/forms.py`), que suma el segundo factor.
Se activa y desactiva desde el perfil
(`/accounts/profile/2fa/activate/` y `/accounts/profile/2fa/deactivate/`).

`/accounts/sudo/` (`apps/core/views/app.py`) pide **reconfirmar la contraseña**
antes de una acción sensible, similar a `sudo` en Unix. El objetivo es que una
sesión compartida no alcance para operaciones delicadas.

## 4. Modelo de permisos: leer antes de prometer

Esto es lo que dice el código, y es lo que hay que decirle al cliente:

- **La API no tiene permisos por usuario.** Textual de la documentación de la
  propia app (`apps/core/api_docs/020-autenticacion.md`): *"Todos los recursos
  son del contribuyente activo: no hay permisos por usuario ni por documento, así
  que cualquier token válido ve lo mismo."*
- Es decir: **cualquier usuario con un token válido ve lo mismo**. El token es de
  **una** persona, pero el alcance de datos es **todo** el contribuyente activo.
- **El segundo factor no aplica a la API**: la documentación dice que el token
  *"permite entrar a la cuenta sin el código de verificación en dos pasos"*.

Traducción comercial honesta: los tokens de API son para integraciones propias o
contratadas con confianza, **no** para repartirse entre el personal.

## 5. Registro y acceso anónimo

- **No hay registro público** una vez creado el primer usuario. No hay vista
  `signup` registrada en las URLs de la aplicación.
- El acceso anónimo que sí existe: `admin/` (el login de Django admin), que exige
  credenciales de superusuario, y `/api/docs/`, `/api/redoc/` y `/api/schema/`,
  que son la documentación de la API.
- **Sobre la documentación de la API**: describe la superficie de la API. No
  entrega datos sin token (la API responde `401`), pero revela qué endpoints
  existen. Si el cliente lo quiere cerrado, hay que bloquear esas rutas en
  Caddy (regla `handle`), no confiar en que "no se ve". **No se verificó** que
  exista un interruptor en la aplicación para desactivarlas.

## 6. Lo que es público dentro del sitio

- `/media/`: los archivos que suben los usuarios (logos) los sirve Caddy en
  `/media/` y **son públicos** —lo dice el README de upstream— con
  `Cache-Control: public, max-age=3600`.
- `/static/`: estáticos públicos, cacheados igual.

**Consecuencia:** un certificado digital **no** debe subirse como logo. Los
certificados se cargan por el flujo de la aplicación, que los cifra con
`FIELD_ENCRYPTION_KEY`.

## 7. Procedimiento seguro de primera cuenta

1. **Antes de exponer el dominio a internet**, crear el usuario (por ejemplo con
   un túnel, o restricting `HTTP_BIND` a `127.0.0.1` hasta terminar).
2. Contraseña larga y única. El primer usuario es superusuario: puede de todo.
3. Activar segundo factor inmediatamente.
4. Anotar el token de API solo si va a usarse, y guardarlo en el gestor de
   secretos. **Generar uno nuevo invalida el anterior al instante** (solo hay uno
   por usuario).
5. Confirmar que `/setup/` ya no muestra el formulario.

## 8. Checklist

- [ ] Primer usuario creado y con segundo factor activo.
- [ ] `/setup/` ya no ofrece el alta.
- [ ] Ningún otro usuario en la base.
- [ ] `SLIM_SEED_DEMO=0` (si estuvo en 1, hay que rehacer con volúmenes nuevos).
- [ ] Nadie usa el usuario `demo`.
- [ ] Tokens de API solo los que corresponden, guardados fuera del repositorio.
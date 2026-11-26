mf-dashboard_Front es un microfront standalone de Angular 20. El host lo monta en home y, por dentro, la UI solo habla con casos de uso. El HTTP queda en los driven-adapters.





La UI no arma las URLs. Las lee el adapter desde environment.ts y el caso de uso solo ve el gateway. El tablero y CCA comparten el mismo HttpClient, pero cada uno tiene su propio gateway y su propio adapter.




mf-dashboard es el home de la Sucursal Virtual Negocios. El host lo monta en la ruta home y el microfront no pinta nada hasta que bootstrap.ts registra providers e interceptores. A partir de ahí, cada ruta decide qué pantalla carga y en qué momento salen las peticiones.

La base de todas las rutas es home. HomeComponent es el padre de Colombia, Filex y contingencia. contactUs y cca son hermanos: no pasan por ese padre.

Arranque, antes de cualquier pantalla
El host resuelve el remote ./main y ejecuta src/main.ts, que importa bootstrap.ts.
setupMicroFrontend inyecta los estilos BDS y crea la aplicación con app.config.ts. Ahí quedan el router, HttpClient, los cuatro interceptores SVN y los gateways.
El router entra por app.routes.ts hacia dashboard.routes.ts.
Nada de esto llama al backend. Las peticiones empiezan cuando un guard o un ngOnInit las dispara.

home — el caso normal
La ruta vacía carga HomeComponent y, como hijo, ColombiaDashboardComponent. El guard de contingencia corre antes de crear ese hijo.

Orden real:

Constructor de Home. Arranca un intervalo que solo refresca la hora en pantalla. No hay HTTP.
ngOnInit de Home, en este orden y sin esperarse entre sí:
Lee el nombre del usuario desde la sesión (UserDataUseCase).
Lanza GET .../ch-ms-channel-contingency/company-status.
Lanza GET .../ch-ms-cca/status con el mfa del usuario. Si el estado no es COMPLETED ni NOT_APPLICABLE, muestra el banner CCA. Si el tipo de usuario es Filex exclusivo, navega a home/filex.
Espera el plan en planType$. Si es Filex, o si sessionStorage.userRelationActivated es true, también navega a home/filex.
Guard contingencyGuard, en paralelo con ese ngOnInit. Vuelve a pedir el estado de contingencia. El servicio lo cachea, así que la segunda llamada no repite el HTTP si la primera ya respondió. Si enabled es verdadero, corta la ruta Colombia y manda a home/contingency antes de crear el tablero.
ngOnInit de Colombia, solo si el guard dejó pasar y el plan no es Filex. Si el plan es Filex, navega a home/filex y no sigue. Si se queda:
En paralelo: POST .../balances/realtime y POST .../balances/start-day.
En paralelo: GET de shortcuts.json.
Consulta el feature flag de atajos y el privilegio de cuentas depósito. Eso no llama a este microfront.
700 ms después de que los dos saldos respondan, loaded pasa a verdadero. Recién ahí se pintan resumen, gráfica, atajos y, si el privilegio lo permite, svn-approvals. Ese componente, al crearse, hace POST .../retrieve-pending-approvals?pageNumber=1&pageSize=7. Las aprobaciones no salen junto con los saldos: esperan a que los saldos terminen y a ese timer.
ngAfterViewInit de Home, cuando el hijo ya está en el DOM:
Si SHOW_USER_ACTIVATION_MODAL es true, el modal de activación puede hacer GET .../resend-otp-invitation. El POST .../activate-user-relation solo ocurre cuando el usuario envía el OTP.
Si mfa o cmfa es 0, encadena POST .../token-state y luego GET .../expiring-token-request-status. Si el token vence dentro de la ventana configurada, sigue con GET .../upcoming-expirations.
Si mfa es 2 y el rol puede administrar tokens de otros, va directo a upcoming-expirations.
Evalúa el centro de mensajes con una bandera local, sin HTTP.
Si sessionStorage.showModal no es false, decide si abre el modal de activar token o el de clave dinámica. El de token, cuando aplica, hace POST .../query-token-request.
ngOnInit de Home es async, y Angular no lo espera. Por eso el hijo Colombia puede empezar a pedir saldos y, un instante después, Home redirige a Filex si el plan llega tarde.

home/filex
No tiene guard. La abre Home cuando el plan o el estado CCA son Filex, o una navegación directa.

En su ngOnInit:

Si el esquema es ESQ0003 y el rol está en ROLES_TITULAR_003, no pide cuentas ni saldos.
Si no, lanza en paralelo getAccounts() y getBalances(). Cuentas hace primero GET .../sync-product-status y, aunque falle, sigue con POST .../deposits-subsidiary/deposits. Saldos es GET .../subsidiary/summary-balance.
Después espera el feature flag de aprobaciones y el árbol de privilegios. El bloque de aprobaciones, si se muestra, dispara el mismo POST de transacciones pendientes.
Envía monitoreo HOME_PRODUCTS_FILEX y el tagging de la página.
Home sigue vivo detrás, así que sus llamadas de contingencia, CCA y token ya salieron o siguen en curso.

home/contingency
El guard entra con negative: true. Solo deja pasar si la contingencia está activa. Si no lo está, devuelve a /.

El ngOnInit de la página no llama al backend. Solo mira privilegios locales: preparar y aprobar.
Si puede aprobar, crea svn-approvals y ahí sí sale el POST de pendientes.
Si no puede aprobar, o si también puede preparar, svn-accounts-preview-contingency en su ngOnInit hace POST .../balances/realtime con { sumyTime: 'REAL' }.
El modal de aviso de contingencia es local. El texto sale de CONTINGENCY_NOTICE_MODAL_AVAILABLE_SERVICES.
home/contactUs
Carga ContactUsComponent como hermano de Home. No ejecuta el padre, no corre el guard de contingencia y no dispara las APIs del tablero.

home/cca
Estas rutas tampoco montan Home. El estado CCA que usan lo dejó en memoria la visita previa a home. Si alguien entra directo y el token de la operación no está validado, validateOperationGuard lo regresa a /home.

Ruta	Cuándo corre	Qué ejecuta
home/cca
Al entrar
Redirige a configurar-canal
home/cca/onboarding-canal
showOnboardingGuard y luego validateOperationGuard
Si el onboarding ya se vio, manda a configurar canal. La página lee complejidad y servicio desde memoria; no hace HTTP propio
home/cca/configurar-canal
Los dos guards
Si el onboarding no se vio, manda al onboarding. Al entrar arma el paso inicial con usuarios y complejidad que ya están en CcaStatusService. El GET de roles sale cuando el paso de roles llega a su ngAfterViewInit
home/cca/granularidad-configuracion
Solo validateOperationGuard. El componente está marcado como flujo viejo
Lee estado y usuarios de memoria y llama getRolesList()
home/cca/configurar-robots
Solo el guard de operación
Igual: estado en memoria y luego la lista de roles
home/cca/cargar-configuracion-robots
Solo el guard de operación. También es flujo viejo
Retoma la configuración de robots ya preparada
Las escrituras de CCA (crear rol, crear grupo, registrar delegados, validar token) no ocurren al entrar. Salen cuando el usuario avanza un paso del wizard.



flowchart TD
  host["Host carga ./main"] --> boot["bootstrap.ts<br/>providers e interceptores"]
  boot --> router["Router en home"]

  router --> home["home<br/>HomeComponent"]
  router --> contact["home/contactUs<br/>sin Home ni APIs del tablero"]
  router --> cca["home/cca<br/>sin Home"]

  home --> h1["Constructor: refresca la hora"]
  h1 --> h2["ngOnInit"]
  h2 --> contingencia["GET company-status"]
  h2 --> ccaStatus["GET ch-ms-cca/status"]
  h2 --> plan["planType$ o sesión Filex"]

  contingencia --> guard["contingencyGuard"]
  plan --> filexNav["Navega a home/filex"]
  ccaStatus --> filexNav

  guard -->|contingencia activa| contingency["home/contingency"]
  guard -->|canal normal| colombia["ColombiaDashboard"]

  colombia --> saldos["En paralelo: POST realtime y POST start-day"]
  colombia --> shortcuts["GET shortcuts.json"]
  saldos --> espera["Espera 700 ms"]
  espera --> pinta["Pinta resumen, gráfica y atajos"]
  pinta --> approvalsCol["Si hay privilegio: POST pending-approvals"]

  home --> after["ngAfterViewInit de Home"]
  after --> otp["Modal de activación: GET OTP y POST activate"]
  after --> token["POST token-state, luego vencimiento y upcoming-expirations"]
  after --> modal["Modal de token o clave dinámica"]

  filexNav --> filex["home/filex"]
  filex --> filexCheck{"ESQ0003 y rol titular"}
  filexCheck -->|sí| filexVacio["No pide cuentas ni saldos"]
  filexCheck -->|no| filexApis["En paralelo: sync + depósitos y summary-balance"]
  filexApis --> filexApprovals["Si el flag lo permite: POST pending-approvals"]

  contingency --> contPriv["Solo privilegios locales"]
  contPriv -->|puede aprobar| contAppr["POST pending-approvals"]
  contPriv -->|prepara o no aprueba| contBal["POST balances/realtime"]

  cca --> ccaGuard["validateOperationGuard"]
  ccaGuard -->|sin token de operación| home
  ccaGuard --> ccaRoutes["onboarding, configurar-canal, robots"]
  ccaRoutes --> ccaMemoria["Lee el estado CCA que dejó home"]
  ccaMemoria --> ccaRoles["GET de roles al abrir el paso"]


El control de acceso de este microfront vive en el navegador. Sirve para decidir qué pantalla mostrar. Quien autoriza una operación tiene que ser el backend, porque cualquiera de estas banderas se puede alterar desde la consola de la página.

Lo que está bien planteado
La sesión no se guarda en el código del microfront. El token de la operación CCA queda en memoria, en CcaAuthService, y no en localStorage. Los window.open del banner y de la verificación de token usan noopener,noreferrer. En producción, app.config.ts registra hostCredentialsInterceptor, activeSessionInterceptor y checkWafErrorInterceptor. En desarrollo el de credenciales del host se omite a propósito, y environment.ts marca production: true.

Hallazgos
Dos provideHttpClient compiten. app.config.ts registra los interceptores SVN. Después, CCA_PROVIDERS registra otro provideHttpClient con su propio commonSFHeadersInterceptor y con authHeaderCcaInterceptor.


cca.providers.ts
Ln 40–41

// HTTP con interceptors propios de CCA
provideHttpClient(withInterceptors([commonSFHeadersInterceptor, authHeaderCcaInterceptor])),
El interceptor de CCA escribe Authorization con el token de sesión, la IP, device-info y session-tracker en cada request que alcanza. authHeaderCcaInterceptor vuelve a escribir Authorization, esta vez con el token de la operación CCA, solo si la request llevó checkCcaToken(). El que corre último gana. Conviene mirar en la pestaña de red una llamada de roles y una de saldos: la de saldos debe salir con el token de sesión y la de CCA con el token de operación. Si el segundo provideHttpClient deja fuera a los interceptores del app.config.ts, las llamadas pierden sesión activa y el chequeo de WAF.

Además, device-id y message-id son un UUID nuevo en cada request. No identifican el dispositivo, así que el rastro de fraude queda partido.

Identidad fija cuando falta uc. Si el usuario no trae uc, la validación del token manda el header cca-ht con el valor UPJ_0012.


validate-token.service.ts
Ln 28–30

const { uc, uis } = this._userDataUseCase.getUserData();
const ucValue = uc ? uc : 'UPJ_0012';
let headers: Record<string, string> = { 'cca-ht': ucValue };
Ese valor no sale de la sesión. Si el servicio de token confía en ese header para saber quién opera, una sesión sin uc se presenta como ese identificador. El fallback hay que quitarlo y cortar la llamada cuando uc no exista.

HTML sin sanitizar en los modales de token. token-activate-modal y activate-dynamic-key meten el texto con Renderer2.setProperty(..., 'innerHTML', ...). Esa vía no pasa por el sanitizador de Angular. El texto viene del environment y trae <b> y <br>. El reemplazo solo cambia <b> por un span; no elimina otras etiquetas. [innerHTML] del banner CCA sí sanitiza. Un texto de configuración con una etiqueta extra se ejecutaría en el modal. Esos textos deberían armarse con plantilla de Angular, no con innerHTML.

Las tarjetas se piden con documento falso. getCards() envía userDocType: 'CC' y userDocumentId: '0' en el body. El documento real está en la sesión y no se usa. Si el backend arma la consulta con ese body, la respuesta no corresponde al usuario. El documento tiene que tomarlo el servicio desde la sesión, no del body que arma el front.

Los guards fallan abiertos. contingencyGuard, ante un error del servicio, deja pasar la navegación. CcaStatusService, ante un error, responde NOT_APPLICABLE y esconde el banner de configuración. validateTokenRequest() en Home, si el servicio falla, resuelve como si no hubiera una solicitud de token en curso y permite abrir el modal. Son decisiones de disponibilidad, no de autorización, pero un fallo de red deja al usuario en el flujo más permisivo.

La ruta Filex se puede forzar en la UI. sessionStorage.userRelationActivated === 'true' alcanza para que Home navegue a home/filex. También redirige si planType$ es Filex o si el estado CCA dice usuario exclusivo Filex. Cambiar esa clave solo cambia la pantalla. El daño aparece si los servicios de depósitos y saldos Filex no vuelven a comprobar el plan en el servidor.

CCA se protege con una bandera en memoria. validateOperationGuard deja entrar si getUserValidOperation() o getAllowOperationWithoutToken() es verdadero. La segunda no se pone en true en el código de la aplicación; solo en pruebas. La primera la pone ValidateTokenService después de un HTTP exitoso. Recargar la página la borra, y eso está bien. No impide llamar los endpoints de roles o delegados por fuera de esta pantalla: el backend tiene que rechazar la operación si el token de CCA no viene o no es válido.

Privilegios solo para pintar. Aprobaciones, cuentas depósito y el tablero de contingencia miran UserRoleService en el cliente. Ocultar un bloque no impide el POST. retrieve-pending-approvals, balances/realtime y el registro de delegados deben autorizarse en el servicio con el mismo privilegio.

Datos que quedan en el navegador
USER_DATA y SESSION_DATA se leen de sessionStorage para la fecha del segundo factor. DEVICE_INFO se vuelve a guardar ahí. El tema, el coachmark y el onboarding viven en localStorage. Nada de eso es el token CCA, pero un script inyectado en la página los lee todos. Por eso el innerHTML de los modales importa: es la vía de ejecución más directa que hay en este microfront.

environment.development.ts deja en el repositorio identificadores de rol y de privilegio, y ALWAYS_SHOW_MODAL_QA: 'true'. No son credenciales. Sí describen quién puede ver el modal de token. En el environment de pipeline esa bandera no debería quedar en true, porque anula el control de “mostrar una vez al día”.

Qué comprobar en el servidor
El front puede ocultar Filex, CCA, aprobaciones y contingencia. No puede impedir la llamada. Estos contratos tienen que rechazar la petición aunque el front la arme:

cca-ht solo se acepta si coincide con la sesión, y se ignora un valor fijo.
El token de operación CCA es obligatorio en roles, grupos, delegados y robots, y no sirve el token de sesión en su lugar.
Saldos, depósitos Filex y transacciones pendientes se filtran por el privilegio y el plan de la sesión, no por el body.
El documento de tarjetas sale de la sesión. Un userDocumentId enviado por el cliente no se usa.




La propuesta ideal para mf-dashboard es tratar el navegador como una capa de presentación. La autorización, la identidad y el token de la operación CCA tienen que decidirse en el servidor. En el microfront hay cinco cambios que cierran los huecos que ya están en el código.

1. Una sola cadena de HTTP
Deja un único provideHttpClient en app.config.ts. El de cca.providers.ts sobra y hoy puede pisar a los interceptores SVN.

El orden que conviene es este:

Headers comunes de security-filters, sin escribir Authorization si otro interceptor ya lo va a definir.
hostCredentialsInterceptor, activeSessionInterceptor y checkWafErrorInterceptor.
authHeaderCcaInterceptor al final, y solo cuando la request lleve checkCcaToken().
Así una llamada de saldos sale con el token de sesión y una de roles o delegados sale con el token de la operación. Hoy los dos interceptores escriben Authorization y gana el que corre último. Conviene comprobarlo en la pestaña de red después de unificarlos.

device-id no debería ser un UUID nuevo en cada request. Un identificador estable de la sesión, generado al entrar y guardado en memoria, alcanza para correlacionar fraude sin persistirlo en localStorage.

2. Identidad solo desde la sesión
En validate-token.service.ts hay que eliminar el fallback UPJ_0012. Si uc no viene en la sesión, la validación del token no se dispara y el usuario ve el error. El header cca-ht tiene que ser el uc de la sesión o no ir.

En getCards(), userDocType: 'CC' y userDocumentId: '0' no deben armarse en el front. El servicio de tarjetas toma el documento de la sesión. Si el contrato exige el documento en el body, se copia desde UserDataUseCase, nunca un valor fijo.

Lo mismo aplica al plan Filex y a los privilegios: el front puede ocultar un bloque, pero balances, deposits-subsidiary y retrieve-pending-approvals tienen que rechazar la llamada si el plan o el privilegio no coinciden con la sesión.

3. El token CCA no se puede sustituir
validateOperationGuard está bien como comodidad de navegación. No es el control. El backend de roles, grupos, delegados y robots debe exigir el token de operación y rechazar el token de sesión en esas rutas.

En el front, getAllowOperationWithoutToken() no debería existir en el guard. No se activa en la aplicación, pero deja una puerta abierta. Y setUserValidOperation(true) solo después de una respuesta exitosa del servicio de validación, como ya hace ValidateTokenService.

El token de operación se queda en memoria, en CcaAuthService. No lo pases a sessionStorage ni a localStorage.

4. Cerrar los fallos abiertos que cambian el flujo
Punto	Comportamiento actual	Propuesta
contingencyGuard
Si el servicio falla, deja entrar al home normal
Reintentar una vez. Si sigue fallando, mostrar un estado de error, no el tablero completo
CcaStatusService
Si falla, responde NOT_APPLICABLE y esconde el banner
Tratar el error como error. El banner de configuración no se da por cumplido
validateTokenRequest() en Home
Si el servicio falla, actúa como si no hubiera solicitud de token
No abrir el modal de activación. Mostrar que no se pudo consultar el estado
userRelationActivated en sessionStorage
Con esa clave el home navega a Filex
La redirección sale solo de planType$ o del estado CCA devuelto por el servicio. La clave de storage no decide la ruta
5. Quitar el HTML inyectado
token-activate-modal y activate-dynamic-key meten el texto con Renderer2 e innerHTML. Angular no sanitiza esa vía. El copy de los modales debe ir en la plantilla, con span para la negrita y la fecha interpolada. [innerHTML] del banner CCA sí sanitiza, pero si el texto es fijo también puede ser plantilla.

ALWAYS_SHOW_MODAL_QA en el environment de pipeline tiene que quedar en false. En QA puede seguir en true para probar el modal. En producción tiene que respetar la regla de mostrarlo una vez al día.

Qué queda fuera del microfront
El host y los servicios tienen que seguir haciendo lo que el front no puede garantizar: cookie de sesión HttpOnly, Content-Security-Policy que impida scripts inline, y rechazo de cualquier operación cuyo privilegio no esté en la sesión. Con eso, aunque alguien fuerce home/filex o arme el POST a mano, el servicio responde 403.
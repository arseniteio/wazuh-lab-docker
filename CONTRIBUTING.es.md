# Contribuir

Esta guía explica cómo proponer un cambio en el laboratorio.

## Antes de empezar

Abre una issue antes de un cambio grande, para acordar el enfoque antes del trabajo. Las correcciones pequeñas pueden ir directamente a una pull request.

Comunica las vulnerabilidades de seguridad en privado a devqs@quersystem.com, no en una issue.

## Entorno de desarrollo

Instala Docker con Compose, Go y Node.js. Clona power-ens-wazuh y oscompliance-ens-wazuh junto a este repositorio.

## Comprobaciones

```bash
make up && make status
```

Para el laboratorio distribuido, ejecuta `make up` y `make status` en `distributed/`, y `make reset` antes de cada prueba.

## Código

- El código, los identificadores, los comentarios, los mensajes de commit y las pull requests van en inglés.
- Sigue las convenciones que ya tiene el repositorio. Los nombres claros, las funciones pequeñas y el manejo explícito de errores van antes que los comentarios.
- Escribe un comentario solo para lo que el código no puede decir: un invariante, una restricción externa o un apaño con su referencia.
- Los tests van en sus propios ficheros.
- Los ficheros de `config/` vienen de wazuh-docker y de OpenSearch Security con sus propias licencias, recogidas en `config/NOTICE`. Mantén ese aviso al día si los cambias.
- Las contraseñas y los certificados se generan en local y nunca se suben al repositorio.

## Commits

Usa [Conventional Commits](https://www.conventionalcommits.org/) con ámbito, en una línea de 72 caracteres como máximo, en imperativo y en minúscula:

```text
fix(install): wait for the rules of the release on workers
```

Tipos: feat, fix, refactor, perf, test, docs, build, ci, chore, style y revert.

## Pull requests

- Un cambio lógico por pull request, en una rama `feat/<tema>` o `fix/<tema>`.
- Las comprobaciones de arriba pasan.
- El comportamiento nuevo trae tests, y una corrección trae un test que falla sin ella.

## Licencia

El proyecto se distribuye bajo AGPL-3.0-only, y Quer System Informática lo ofrece también con una licencia comercial. Para que las dos sean posibles, Quer System Informática necesita los derechos de cada contribución. Antes de que se fusione tu primera pull request, firma el acuerdo de licencia de contribuidor de Quer System Informática. Pídelo en devqs@quersystem.com.

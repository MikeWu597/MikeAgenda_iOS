(function (global) {
    'use strict';

    let counter = 0;
    const pending = new Map();
    const hasNativeBridge = !!(global.webkit && global.webkit.messageHandlers && global.webkit.messageHandlers.mikeAgenda);

    function nextId(prefix) {
        counter += 1;
        return prefix + '-' + Date.now() + '-' + counter;
    }

    function clonePayload(payload) {
        return payload && typeof payload === 'object' ? JSON.parse(JSON.stringify(payload)) : {};
    }

    function dispatchToNative(action, payload) {
        return new Promise(function (resolve, reject) {
            const id = nextId(action);
            pending.set(id, { resolve: resolve, reject: reject });

            const message = {
                id: id,
                action: action,
                payload: clonePayload(payload)
            };

            try {
                global.webkit.messageHandlers.mikeAgenda.postMessage(message);
            } catch (error) {
                pending.delete(id);
                reject(error instanceof Error ? error : new Error(String(error)));
            }
        });
    }

    async function fallbackRequest(options) {
        const headers = options.headers || {};
        const response = await fetch(options.url, {
            method: options.method || 'GET',
            headers: headers,
            body: options.body || undefined
        });

        const text = await response.text();
        let json = null;

        try {
            json = text ? JSON.parse(text) : null;
        } catch (error) {
            json = null;
        }

        return {
            ok: response.ok,
            status: response.status,
            text: text,
            json: json,
            headers: {}
        };
    }

    async function fallbackStorage(action, payload) {
        const key = payload.key;

        if (action === 'storageGet') {
            return { value: global.localStorage.getItem(key) };
        }

        if (action === 'storageSet') {
            global.localStorage.setItem(key, payload.value || '');
            return { ok: true };
        }

        if (action === 'storageRemove') {
            global.localStorage.removeItem(key);
            return { ok: true };
        }

        throw new Error('Unsupported fallback storage action');
    }

    const bridge = {
        isNative: hasNativeBridge,

        invoke: function (action, payload) {
            if (hasNativeBridge) {
                return dispatchToNative(action, payload || {});
            }

            if (action === 'request') {
                return fallbackRequest(payload || {});
            }

            if (action === 'storageGet' || action === 'storageSet' || action === 'storageRemove') {
                return fallbackStorage(action, payload || {});
            }

            return Promise.reject(new Error('Bridge unavailable'));
        },

        request: function (options) {
            return this.invoke('request', options);
        },

        async getItem(key, secure) {
            const result = await this.invoke('storageGet', { key: key, secure: !!secure });
            return result && Object.prototype.hasOwnProperty.call(result, 'value') ? result.value : null;
        },

        async setItem(key, value, secure) {
            return this.invoke('storageSet', { key: key, value: value, secure: !!secure });
        },

        async removeItem(key, secure) {
            return this.invoke('storageRemove', { key: key, secure: !!secure });
        },

        __dispatch: function (response) {
            const id = response && response.id;
            if (!id || !pending.has(id)) {
                return;
            }

            const deferred = pending.get(id);
            pending.delete(id);

            if (response.error) {
                deferred.reject(new Error(response.error));
                return;
            }

            deferred.resolve(response);
        }
    };

    global.MikeAgendaBridge = bridge;
})(window);
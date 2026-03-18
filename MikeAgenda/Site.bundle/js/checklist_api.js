(function (global) {
    'use strict';

    const LOGIN_URL = '/login.html';

    function getSessionFromCookie() {
        const cookies = document.cookie.split(';');
        for (const cookie of cookies) {
            const [name, value] = cookie.trim().split('=');
            if (name === 'session') return decodeURIComponent(value);
        }
        return null;
    }

    function redirectToLogin() {
        window.location.href = LOGIN_URL;
    }

    function ensureSessionOrRedirect() {
        const session = getSessionFromCookie();
        if (!session) {
            redirectToLogin();
            return null;
        }
        return session;
    }

    async function fetchJson(url, options) {
        const res = await fetch(url, options);
        if (res.status === 401) {
            redirectToLogin();
            return null;
        }
        let data;
        try {
            data = await res.json();
        } catch (e) {
            throw new Error('服务返回非 JSON');
        }
        return { res, data };
    }

    function normalizeOrderIndex(v) {
        const n = Number(v);
        return Number.isFinite(n) ? n : 0;
    }

    function nextOrderIndex(list) {
        if (!Array.isArray(list) || list.length === 0) return 0;
        let maxOrder = -1;
        for (const row of list) {
            const n = normalizeOrderIndex(row && row.order_index);
            if (n > maxOrder) maxOrder = n;
        }
        return maxOrder + 1;
    }

    const checklistApi = {
        getSessionFromCookie,
        ensureSessionOrRedirect,
        normalizeOrderIndex,
        nextOrderIndex,

        async getChecklists() {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const { data } = await fetchJson('/api/getChecklists', {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    session
                }
            }) || {};

            return data || null;
        },

        async getChecklist(id) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const { data } = await fetchJson(`/api/getChecklist/${encodeURIComponent(String(id))}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    session
                }
            }) || {};

            return data || null;
        },

        async createChecklist(payload) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const body = {
                session,
                name: payload && payload.name,
                orderIndex: payload && payload.orderIndex
            };

            const { data } = await fetchJson('/api/createChecklist', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify(body)
            }) || {};

            return data || null;
        },

        async updateChecklist(id, payload) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const body = {
                session,
                name: payload && payload.name,
                orderIndex: payload && payload.orderIndex
            };

            const { data } = await fetchJson(`/api/updateChecklist/${encodeURIComponent(String(id))}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify(body)
            }) || {};

            return data || null;
        },

        async deleteChecklist(id) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const { data } = await fetchJson(`/api/deleteChecklist/${encodeURIComponent(String(id))}`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify({ session })
            }) || {};

            return data || null;
        },

        async createChecklistItem(payload) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const body = {
                session,
                checklistId: payload && payload.checklistId,
                name: payload && payload.name,
                orderIndex: payload && payload.orderIndex
            };

            const { data } = await fetchJson('/api/createChecklistItem', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify(body)
            }) || {};

            return data || null;
        },

        async updateChecklistItem(id, payload) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const body = {
                session,
                name: payload && payload.name,
                orderIndex: payload && payload.orderIndex,
                checked: payload && payload.checked
            };

            const { data } = await fetchJson(`/api/updateChecklistItem/${encodeURIComponent(String(id))}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify(body)
            }) || {};

            return data || null;
        },

        async deleteChecklistItem(id) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const { data } = await fetchJson(`/api/deleteChecklistItem/${encodeURIComponent(String(id))}`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify({ session })
            }) || {};

            return data || null;
        },

        async updateChecklistItemStatus(id, checked) {
            const session = ensureSessionOrRedirect();
            if (!session) return null;

            const { data } = await fetchJson('/api/updateChecklistItemStatus', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    session
                },
                body: JSON.stringify({
                    session,
                    id,
                    checked
                })
            }) || {};

            return data || null;
        }
    };

    global.MikeChecklistApi = checklistApi;
})(window);

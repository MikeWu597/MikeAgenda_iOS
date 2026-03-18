(function () {
    'use strict';

    var createApp = Vue.createApp;
    var ElMessage = ElementPlus.ElMessage;
    var ElMessageBox = ElementPlus.ElMessageBox;

    var STORAGE_KEYS = {
        domain: 'mikeagenda.domain',
        username: 'mikeagenda.username',
        password: 'mikeagenda.password',
        session: 'mikeagenda.session'
    };

    var COURSE_DAY_OPTIONS = [
        { value: 0, label: '周日' },
        { value: 1, label: '周一' },
        { value: 2, label: '周二' },
        { value: 3, label: '周三' },
        { value: 4, label: '周四' },
        { value: 5, label: '周五' },
        { value: 6, label: '周六' }
    ];

    function defaultSummary() {
        return {
            pendingItems: 0,
            doneItems: 0,
            todayCycles: 0,
            urgentRenewals: 0,
            activeProjects: 0
        };
    }

    function defaultDialogs() {
        return {
            item: false,
            category: false,
            cycle: false,
            course: false,
            project: false,
            renewal: false,
            checklist: false,
            checklistItem: false
        };
    }

    function defaultEditors() {
        return {
            itemId: '',
            categoryId: '',
            cycleId: '',
            courseId: '',
            projectId: '',
            renewalId: '',
            checklistId: '',
            checklistItemId: '',
            renewalCategoryId: ''
        };
    }

    function defaultItemDraft() {
        return {
            title: '',
            description: '',
            deadline: '',
            plannedTime: '',
            category: []
        };
    }

    function defaultCategoryDraft() {
        return {
            name: '',
            color: '#1ea7a8',
            note: ''
        };
    }

    function defaultCycleDraft() {
        return {
            name: '',
            note: '',
            next: '',
            type: 'daily',
            weekDays: [],
            monthDay: 1,
            monthLastOffset: 1
        };
    }

    function defaultCourseDraft() {
        return {
            id: '',
            course_name: '',
            course_code: '',
            venue: '',
            instructor_name: '',
            day: 1,
            course_color: '#1ea7a8',
            start_time: '09:00:00',
            end_time: '10:00:00',
            is_active: true
        };
    }

    function defaultProjectDraft() {
        return {
            name: '',
            description: '',
            color: '#1ea7a8'
        };
    }

    function defaultRenewalDraft() {
        return {
            name: '',
            description: '',
            categoryId: '',
            expiryDate: formatDateForPicker(new Date()),
            reminderDays: 7
        };
    }

    function defaultChecklistDraft() {
        return {
            name: '',
            orderIndex: 0
        };
    }

    function defaultChecklistItemDraft() {
        return {
            name: '',
            orderIndex: 0
        };
    }

    function defaultRenewalCategoryDraft() {
        return {
            name: '',
            color: '#1ea7a8',
            description: ''
        };
    }

    function defaultDrafts() {
        return {
            item: defaultItemDraft(),
            category: defaultCategoryDraft(),
            cycle: defaultCycleDraft(),
            course: defaultCourseDraft(),
            project: defaultProjectDraft(),
            renewal: defaultRenewalDraft(),
            checklist: defaultChecklistDraft(),
            checklistItem: defaultChecklistItemDraft(),
            renewalCategory: defaultRenewalCategoryDraft()
        };
    }

    function defaultFilters() {
        return {
            itemSearch: '',
            cycleSearch: '',
            courseDay: 'all',
            projectSearch: '',
            checklistSearch: '',
            renewalSearch: '',
            categorySearch: ''
        };
    }

    function pad2(value) {
        return value < 10 ? '0' + value : String(value);
    }

    function parseDate(value) {
        if (!value) {
            return null;
        }

        if (value instanceof Date) {
            return isNaN(value.getTime()) ? null : value;
        }

        var text = String(value).trim();
        if (!text) {
            return null;
        }

        if (/^\d{8}$/.test(text)) {
            return new Date(
                Number(text.slice(0, 4)),
                Number(text.slice(4, 6)) - 1,
                Number(text.slice(6, 8)),
                0,
                0,
                0,
                0
            );
        }

        if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
            return new Date(text + 'T00:00:00');
        }

        if (text.indexOf(' ') > -1 && text.indexOf('T') === -1) {
            text = text.replace(' ', 'T');
        }

        var parsed = new Date(text);
        return isNaN(parsed.getTime()) ? null : parsed;
    }

    function formatDateTime(value) {
        var date = parseDate(value);
        if (!date) {
            return value || '-';
        }

        return [
            date.getFullYear(),
            '/',
            pad2(date.getMonth() + 1),
            '/',
            pad2(date.getDate()),
            ' ',
            pad2(date.getHours()),
            ':',
            pad2(date.getMinutes())
        ].join('');
    }

    function formatDateOnly(value) {
        var date = parseDate(value);
        if (!date) {
            return value || '-';
        }

        return [date.getFullYear(), '/', pad2(date.getMonth() + 1), '/', pad2(date.getDate())].join('');
    }

    function formatDateTimeForPicker(value) {
        var date = parseDate(value);
        if (!date) {
            return '';
        }

        return [
            date.getFullYear(),
            '-',
            pad2(date.getMonth() + 1),
            '-',
            pad2(date.getDate()),
            ' ',
            pad2(date.getHours()),
            ':',
            pad2(date.getMinutes()),
            ':',
            pad2(date.getSeconds())
        ].join('');
    }

    function formatDateForPicker(date) {
        var current = parseDate(date);
        if (!current) {
            current = new Date();
        }
        return [current.getFullYear(), '-', pad2(current.getMonth() + 1), '-', pad2(current.getDate())].join('');
    }

    function formatUptime(seconds) {
        var total = Number(seconds) || 0;
        var days = Math.floor(total / 86400);
        var hours = Math.floor((total % 86400) / 3600);
        var minutes = Math.floor((total % 3600) / 60);

        if (days > 0) {
            return days + ' 天 ' + hours + ' 小时';
        }
        if (hours > 0) {
            return hours + ' 小时 ' + minutes + ' 分钟';
        }
        return minutes + ' 分钟';
    }

    function normalizeText(value) {
        return String(value == null ? '' : value).trim().toLowerCase();
    }

    function sortByDateValue(left, right) {
        var leftDate = parseDate(left);
        var rightDate = parseDate(right);
        var leftValue = leftDate ? leftDate.getTime() : Number.MAX_SAFE_INTEGER;
        var rightValue = rightDate ? rightDate.getTime() : Number.MAX_SAFE_INTEGER;
        return leftValue - rightValue;
    }

    function sortItems(items) {
        return (items || []).slice().sort(function (left, right) {
            var deadlineCompare = sortByDateValue(left.deadline, right.deadline);
            if (deadlineCompare !== 0) {
                return deadlineCompare;
            }

            var plannedCompare = sortByDateValue(left.planned_time, right.planned_time);
            if (plannedCompare !== 0) {
                return plannedCompare;
            }

            return String(left.title || '').localeCompare(String(right.title || ''), 'zh-Hans-CN');
        });
    }

    function parseCategoryArray(value) {
        if (!value) {
            return [];
        }

        if (Array.isArray(value)) {
            return value.map(function (entry) { return Number(entry); }).filter(function (entry) { return !isNaN(entry); });
        }

        try {
            var parsed = JSON.parse(value);
            return Array.isArray(parsed) ? parsed.map(function (entry) { return Number(entry); }).filter(function (entry) { return !isNaN(entry); }) : [];
        } catch (error) {
            return [];
        }
    }

    function parseCyclePayload(value) {
        var fallback = {
            type: 'daily',
            configText: '{}'
        };

        if (!value) {
            return fallback;
        }

        try {
            var parsed = typeof value === 'string' ? JSON.parse(value) : value;
            return {
                type: parsed && parsed.cycle ? parsed.cycle : 'daily',
                configText: parsed && parsed.config ? parsed.config : '{}'
            };
        } catch (error) {
            return fallback;
        }
    }

    function parseJSON(value, fallback) {
        try {
            return JSON.parse(value);
        } catch (error) {
            return fallback;
        }
    }

    function extractHost(value) {
        try {
            return new URL(value).host;
        } catch (error) {
            return value || '未连接';
        }
    }

    function ensureArray(value) {
        return Array.isArray(value) ? value : [];
    }

    function isTodayCourse(courseDay) {
        return Number(courseDay) === new Date().getDay();
    }

    function daysUntil(dateText) {
        var target = parseDate(dateText);
        if (!target) {
            return Number.MAX_SAFE_INTEGER;
        }

        var today = new Date();
        today.setHours(0, 0, 0, 0);
        target.setHours(0, 0, 0, 0);
        return Math.round((target.getTime() - today.getTime()) / 86400000);
    }

    function todayKey() {
        var now = new Date();
        return [now.getFullYear(), pad2(now.getMonth() + 1), pad2(now.getDate())].join('');
    }

    function nextOrderIndex(items, fieldName) {
        var key = fieldName || 'order_index';
        var list = ensureArray(items);
        var max = -1;
        list.forEach(function (entry) {
            var numeric = Number(entry && entry[key]);
            if (!isNaN(numeric) && numeric > max) {
                max = numeric;
            }
        });
        return max + 1;
    }

    function withSession(body, session) {
        var nextBody = {};
        var source = body || {};
        Object.keys(source).forEach(function (key) {
            nextBody[key] = source[key];
        });
        nextBody.session = session;
        return nextBody;
    }

    var app = createApp({
        data: function () {
            return {
                session: '',
                connectionForm: {
                    domain: '',
                    username: '',
                    password: ''
                },
                ui: {
                    booting: true,
                    mode: 'setup',
                    connectionError: '',
                    savingConnection: false,
                    refreshing: false,
                    activeTab: 'dashboard',
                    moreTab: 'projects',
                    itemView: 'pending',
                    projectRecordsVisible: false,
                    renewalCategoryManagerVisible: false
                },
                dialogs: defaultDialogs(),
                editors: defaultEditors(),
                drafts: defaultDrafts(),
                filters: defaultFilters(),
                settingsForm: {
                    teachingEnabled: true,
                    imageLimitMb: 50
                },
                summary: defaultSummary(),
                items: [],
                doneItems: [],
                categories: [],
                cycles: [],
                todayCycles: [],
                courses: [],
                projects: [],
                renewals: [],
                renewalCategories: [],
                checklists: [],
                selectedChecklist: null,
                selectedProject: null,
                projectRecords: [],
                systemStatus: null,
                courseDayOptions: COURSE_DAY_OPTIONS
            };
        },
        computed: {
            hasSavedProfile: function () {
                return !!(this.connectionForm.domain && this.connectionForm.username && this.connectionForm.password);
            },
            hasSession: function () {
                return !!this.session;
            },
            connectedHost: function () {
                return this.connectionForm.domain ? extractHost(this.normalizeDomain(this.connectionForm.domain)) : '未连接';
            },
            currentTitle: function () {
                if (this.ui.activeTab === 'dashboard') {
                    return '概览';
                }
                if (this.ui.activeTab === 'items') {
                    return '事项';
                }
                if (this.ui.activeTab === 'cycles') {
                    return '周期';
                }
                if (this.ui.activeTab === 'courses') {
                    return '课程';
                }
                return '更多';
            },
            currentSubtitle: function () {
                if (this.ui.activeTab === 'dashboard') {
                    return '今天先处理最紧急的事项、循环和课程。';
                }
                if (this.ui.activeTab === 'items') {
                    return '事项支持分类、计划时间和完成状态切换。';
                }
                if (this.ui.activeTab === 'cycles') {
                    return '循环日程会按服务端规则计算下次触发时间。';
                }
                if (this.ui.activeTab === 'courses') {
                    return '课程页按星期整理，适合手机快速查看。';
                }
                if (this.ui.moreTab === 'projects') {
                    return '项目、检查表、续费、分类和设置都集中在这里。';
                }
                if (this.ui.moreTab === 'checklists') {
                    return '检查表支持多份清单和逐项勾选。';
                }
                if (this.ui.moreTab === 'renewals') {
                    return '续费提醒按到期日和提醒天数自动计算。';
                }
                if (this.ui.moreTab === 'categories') {
                    return '分类用于事项标记和筛选。';
                }
                return '连接配置和服务器设置也在这里管理。';
            },
            dashboardPendingPreview: function () {
                return sortItems(this.items).slice(0, 4);
            },
            todayCoursePreview: function () {
                return this.courses
                    .filter(function (course) { return isTodayCourse(course.day); })
                    .sort(function (left, right) {
                        return String(left.start_time || '').localeCompare(String(right.start_time || ''));
                    })
                    .slice(0, 4);
            },
            urgentRenewalPreview: function () {
                return this.filteredUrgentRenewals.slice(0, 4);
            },
            filteredUrgentRenewals: function () {
                return this.renewals
                    .filter(function (renewal) {
                        return daysUntil(renewal.expiry_date) <= Number(renewal.reminder_days || 0);
                    })
                    .sort(function (left, right) {
                        return daysUntil(left.expiry_date) - daysUntil(right.expiry_date);
                    });
            },
            visibleItems: function () {
                var searchText = normalizeText(this.filters.itemSearch);
                var source = this.ui.itemView === 'pending' ? this.items : this.doneItems;
                return sortItems(source).filter(function (item) {
                    if (!searchText) {
                        return true;
                    }
                    var haystack = normalizeText(item.title) + ' ' + normalizeText(item.description);
                    return haystack.indexOf(searchText) > -1;
                });
            },
            filteredCycles: function () {
                var searchText = normalizeText(this.filters.cycleSearch);
                return ensureArray(this.cycles)
                    .slice()
                    .sort(function (left, right) {
                        return sortByDateValue(left.next, right.next);
                    })
                    .filter(function (cycle) {
                        return !searchText || normalizeText(cycle.name).indexOf(searchText) > -1;
                    });
            },
            visibleCourseColumns: function () {
                var selected = this.filters.courseDay;
                return this.courseDayOptions
                    .filter(function (day) {
                        return selected === 'all' || String(day.value) === String(selected);
                    })
                    .map(function (day) {
                        return {
                            value: day.value,
                            label: day.label,
                            items: this.courses
                                .filter(function (course) { return Number(course.day) === Number(day.value); })
                                .slice()
                                .sort(function (left, right) {
                                    return String(left.start_time || '').localeCompare(String(right.start_time || ''));
                                })
                        };
                    }, this);
            },
            filteredProjects: function () {
                var searchText = normalizeText(this.filters.projectSearch);
                return ensureArray(this.projects)
                    .slice()
                    .sort(function (left, right) {
                        return String(left.name || '').localeCompare(String(right.name || ''), 'zh-Hans-CN');
                    })
                    .filter(function (project) {
                        if (!searchText) {
                            return true;
                        }
                        return (normalizeText(project.name) + ' ' + normalizeText(project.description)).indexOf(searchText) > -1;
                    });
            },
            filteredChecklists: function () {
                var searchText = normalizeText(this.filters.checklistSearch);
                return ensureArray(this.checklists).filter(function (checklist) {
                    return !searchText || normalizeText(checklist.name).indexOf(searchText) > -1;
                });
            },
            filteredRenewals: function () {
                var searchText = normalizeText(this.filters.renewalSearch);
                return ensureArray(this.renewals)
                    .slice()
                    .sort(function (left, right) {
                        return daysUntil(left.expiry_date) - daysUntil(right.expiry_date);
                    })
                    .filter(function (renewal) {
                        if (!searchText) {
                            return true;
                        }
                        return (normalizeText(renewal.name) + ' ' + normalizeText(renewal.description)).indexOf(searchText) > -1;
                    });
            },
            filteredCategories: function () {
                var searchText = normalizeText(this.filters.categorySearch);
                return ensureArray(this.categories)
                    .slice()
                    .sort(function (left, right) {
                        return String(left.name || '').localeCompare(String(right.name || ''), 'zh-Hans-CN');
                    })
                    .filter(function (category) {
                        if (!searchText) {
                            return true;
                        }
                        return (normalizeText(category.name) + ' ' + normalizeText(category.note)).indexOf(searchText) > -1;
                    });
            },
            checklistCompletionRate: function () {
                if (!this.selectedChecklist || !Array.isArray(this.selectedChecklist.items) || this.selectedChecklist.items.length === 0) {
                    return 0;
                }

                var checked = this.selectedChecklist.items.filter(function (item) { return !!item.checked; }).length;
                return Math.round((checked / this.selectedChecklist.items.length) * 100);
            },
            checklistCompletionText: function () {
                if (!this.selectedChecklist || !Array.isArray(this.selectedChecklist.items)) {
                    return '0 / 0';
                }
                var checked = this.selectedChecklist.items.filter(function (item) { return !!item.checked; }).length;
                return checked + ' / ' + this.selectedChecklist.items.length;
            }
        },
        methods: {
            formatDateTime: function (value) {
                return formatDateTime(value);
            },
            formatDateOnly: function (value) {
                return formatDateOnly(value);
            },
            formatUptime: function (seconds) {
                return formatUptime(seconds);
            },
            normalizeDomain: function (value) {
                var text = String(value || '').trim();
                if (!text) {
                    return '';
                }

                if (text.slice(-1) === '/') {
                    text = text.slice(0, -1);
                }

                return text;
            },
            buildUrl: function (path) {
                var domain = this.normalizeDomain(this.connectionForm.domain);
                if (!domain) {
                    throw new Error('请先配置服务域名');
                }
                return domain + path;
            },
            storageGet: function (key, secure) {
                return MikeAgendaBridge.getItem(key, !!secure);
            },
            storageSet: function (key, value, secure) {
                return MikeAgendaBridge.setItem(key, value || '', !!secure);
            },
            storageRemove: function (key, secure) {
                return MikeAgendaBridge.removeItem(key, !!secure);
            },
            loadStoredProfile: async function () {
                var result = await Promise.all([
                    this.storageGet(STORAGE_KEYS.domain, false),
                    this.storageGet(STORAGE_KEYS.username, false),
                    this.storageGet(STORAGE_KEYS.password, true),
                    this.storageGet(STORAGE_KEYS.session, true)
                ]);

                this.connectionForm.domain = result[0] || '';
                this.connectionForm.username = result[1] || '';
                this.connectionForm.password = result[2] || '';
                this.session = result[3] || '';
            },
            persistProfile: async function () {
                await Promise.all([
                    this.storageSet(STORAGE_KEYS.domain, this.connectionForm.domain, false),
                    this.storageSet(STORAGE_KEYS.username, this.connectionForm.username, false),
                    this.storageSet(STORAGE_KEYS.password, this.connectionForm.password, true)
                ]);
            },
            persistSession: function () {
                return this.storageSet(STORAGE_KEYS.session, this.session || '', true);
            },
            clearSessionStorage: async function () {
                this.session = '';
                await this.storageRemove(STORAGE_KEYS.session, true);
            },
            resetLoadedData: function () {
                this.items = [];
                this.doneItems = [];
                this.categories = [];
                this.cycles = [];
                this.todayCycles = [];
                this.courses = [];
                this.projects = [];
                this.renewals = [];
                this.renewalCategories = [];
                this.checklists = [];
                this.selectedChecklist = null;
                this.selectedProject = null;
                this.projectRecords = [];
                this.systemStatus = null;
                this.summary = defaultSummary();
            },
            validateConnectionForm: function () {
                var domain = this.normalizeDomain(this.connectionForm.domain);
                if (!domain) {
                    throw new Error('请输入服务域名');
                }
                if (!/^https?:\/\//i.test(domain)) {
                    throw new Error('服务域名必须包含 http:// 或 https://');
                }
                try {
                    new URL(domain);
                } catch (error) {
                    throw new Error('服务域名格式无效');
                }
                if (!String(this.connectionForm.username || '').trim()) {
                    throw new Error('请输入账户名');
                }
                if (!String(this.connectionForm.password || '').trim()) {
                    throw new Error('请输入密码');
                }
                this.connectionForm.domain = domain;
            },
            requestJSON: async function (options) {
                var headers = {};
                var hasBody = options.body != null;
                if (hasBody) {
                    headers['Content-Type'] = 'application/json';
                }

                if (options.sessionHeader && this.session) {
                    headers.session = this.session;
                }

                var payload = options.body;
                if (options.sessionBody && this.session) {
                    payload = withSession(payload, this.session);
                }

                var response = await MikeAgendaBridge.request({
                    url: this.buildUrl(options.path),
                    method: options.method || 'GET',
                    headers: headers,
                    body: hasBody ? JSON.stringify(payload) : undefined,
                    timeout: 30000
                });

                var data = response.json;
                if (data == null && response.text) {
                    data = parseJSON(response.text, null);
                }

                if (response.status === 401 && !options.skipRelogin && this.connectionForm.password) {
                    await this.performLogin(false, true);
                    return this.requestJSON({
                        path: options.path,
                        method: options.method,
                        body: options.body,
                        sessionHeader: options.sessionHeader,
                        sessionBody: options.sessionBody,
                        skipRelogin: true
                    });
                }

                if (!response.ok || (data && data.success === false)) {
                    var message = (data && data.message) || response.text || '请求失败';
                    var error = new Error(message);
                    error.status = response.status;
                    throw error;
                }

                return data || {};
            },
            requestSystemStatus: async function () {
                var response = await MikeAgendaBridge.request({
                    url: this.buildUrl('/api/getSystemStatus'),
                    method: 'GET',
                    headers: {},
                    timeout: 15000
                });

                var data = response.json;
                if (data == null && response.text) {
                    data = parseJSON(response.text, null);
                }

                if (!response.ok || (data && data.success === false)) {
                    throw new Error((data && data.message) || response.text || '加载系统状态失败');
                }

                return data || {};
            },
            bootstrap: async function () {
                try {
                    await this.loadStoredProfile();
                    if (this.hasSavedProfile) {
                        await this.enterApplication(false);
                    } else {
                        this.ui.mode = 'setup';
                    }
                } catch (error) {
                    this.ui.mode = 'setup';
                    this.ui.connectionError = error.message || '初始化失败';
                    await this.clearSessionStorage().catch(function () { return null; });
                } finally {
                    this.ui.booting = false;
                }
            },
            enterApplication: async function (showSuccess) {
                if (!this.session) {
                    await this.performLogin(showSuccess !== false, true);
                }

                await this.refreshAll();
                this.ui.mode = 'app';
                this.ui.connectionError = '';
            },
            saveConnection: async function () {
                this.ui.connectionError = '';
                this.ui.savingConnection = true;

                try {
                    this.validateConnectionForm();
                    await this.persistProfile();
                    await this.clearSessionStorage();
                    await this.enterApplication(true);
                } catch (error) {
                    this.ui.mode = 'setup';
                    this.ui.connectionError = error.message || '连接失败';
                } finally {
                    this.ui.savingConnection = false;
                }
            },
            retryConnection: async function () {
                if (!this.hasSavedProfile) {
                    ElMessage.warning('没有可用的已保存配置');
                    return;
                }
                await this.saveConnection();
            },
            performLogin: async function (showSuccess, silent) {
                this.validateConnectionForm();

                var response = await MikeAgendaBridge.request({
                    url: this.buildUrl('/login'),
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        username: this.connectionForm.username,
                        password: this.connectionForm.password
                    }),
                    timeout: 20000
                });

                var data = response.json;
                if (data == null && response.text) {
                    data = parseJSON(response.text, null);
                }

                if (!response.ok || !data || !data.success || !data.session) {
                    var message = (data && data.message) || '登录失败，请检查域名、账户名和密码';
                    await this.clearSessionStorage().catch(function () { return null; });
                    throw new Error(message);
                }

                this.session = data.session;
                await this.persistSession();

                if (showSuccess && !silent) {
                    ElMessage.success('连接成功，正在同步数据');
                }
            },
            logout: async function () {
                try {
                    await ElMessageBox.confirm('退出后会清空当前会话，但保留域名和账户配置。', '退出登录', {
                        type: 'warning',
                        confirmButtonText: '退出',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                await this.clearSessionStorage();
                this.resetLoadedData();
                this.ui.mode = 'setup';
                this.ui.connectionError = '';
                ElMessage.success('已退出登录');
            },
            reconfigureConnection: function () {
                this.ui.mode = 'setup';
                this.ui.connectionError = '';
            },
            clearStoredProfile: async function () {
                try {
                    await ElMessageBox.confirm('这会清空域名、账户、密码和会话，本机需要重新配置。', '清空本地配置', {
                        type: 'warning',
                        confirmButtonText: '清空',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                await Promise.all([
                    this.storageRemove(STORAGE_KEYS.domain, false),
                    this.storageRemove(STORAGE_KEYS.username, false),
                    this.storageRemove(STORAGE_KEYS.password, true),
                    this.storageRemove(STORAGE_KEYS.session, true)
                ]);

                this.connectionForm.domain = '';
                this.connectionForm.username = '';
                this.connectionForm.password = '';
                this.session = '';
                this.resetLoadedData();
                this.ui.mode = 'setup';
                this.ui.connectionError = '';
                ElMessage.success('本地配置已清空');
            },
            syncSummary: function () {
                this.summary.pendingItems = this.items.length;
                this.summary.doneItems = this.doneItems.length;
                this.summary.todayCycles = this.todayCycles.length;
                this.summary.urgentRenewals = this.filteredUrgentRenewals.length;
                this.summary.activeProjects = this.projects.length;
            },
            refreshAll: async function () {
                this.ui.refreshing = true;
                var failures = [];
                var tasks = [
                    this.refreshItems,
                    this.refreshCategories,
                    this.refreshCycles,
                    this.refreshCourses,
                    this.refreshProjects,
                    this.refreshRenewals,
                    this.refreshChecklists,
                    this.refreshSettings,
                    this.refreshSystemStatus
                ];

                for (var index = 0; index < tasks.length; index += 1) {
                    try {
                        await tasks[index].call(this);
                    } catch (error) {
                        failures.push(error.message || '加载失败');
                    }
                }

                this.syncSummary();
                this.ui.refreshing = false;

                if (failures.length) {
                    ElMessage.warning('部分数据未能加载：' + failures[0]);
                }
            },
            refreshCurrent: async function () {
                await this.refreshAll();
            },
            refreshItems: async function () {
                var results = await Promise.all([
                    this.requestJSON({ path: '/api/getItems', method: 'GET', sessionHeader: true }),
                    this.requestJSON({ path: '/api/getDoneItems', method: 'GET', sessionHeader: true })
                ]);

                this.items = ensureArray(results[0].items);
                this.doneItems = ensureArray(results[1].items);
                this.syncSummary();
            },
            refreshCategories: async function () {
                var data = await this.requestJSON({ path: '/api/getCategories', method: 'POST', sessionBody: true, body: {} });
                this.categories = ensureArray(data.categories);
            },
            refreshCycles: async function () {
                var results = await Promise.all([
                    this.requestJSON({ path: '/api/getCycles', method: 'GET', sessionHeader: true }),
                    this.requestJSON({ path: '/api/getTodayCycles', method: 'POST', sessionHeader: true, body: { date: todayKey() } })
                ]);
                this.cycles = ensureArray(results[0].cycles);
                this.todayCycles = ensureArray(results[1].cycles);
                this.syncSummary();
            },
            refreshCourses: async function () {
                var data = await this.requestJSON({ path: '/api/getCourses', method: 'GET', sessionHeader: true });
                this.courses = ensureArray(data.courses).map(function (course) {
                    var nextCourse = {};
                    Object.keys(course).forEach(function (key) {
                        nextCourse[key] = course[key];
                    });
                    nextCourse.day = Number(course.day);
                    nextCourse.is_active = !!course.is_active;
                    return nextCourse;
                });
            },
            refreshProjects: async function () {
                var data = await this.requestJSON({ path: '/api/getProjects', method: 'GET', sessionHeader: true });
                this.projects = ensureArray(data.projects);
                this.syncSummary();
            },
            refreshRenewals: async function () {
                var results = await Promise.all([
                    this.requestJSON({ path: '/api/getAllRenewals', method: 'POST', sessionBody: true, body: {} }),
                    this.requestJSON({ path: '/api/getAllRenewalCategories', method: 'POST', sessionBody: true, body: {} })
                ]);
                this.renewals = ensureArray(results[0].data);
                this.renewalCategories = ensureArray(results[1].data);
                this.syncSummary();
            },
            refreshChecklists: async function () {
                var data = await this.requestJSON({ path: '/api/getChecklists', method: 'GET', sessionHeader: true });
                var previousId = this.selectedChecklist ? String(this.selectedChecklist.id) : '';
                this.checklists = ensureArray(data.checklists);

                if (!this.checklists.length) {
                    this.selectedChecklist = null;
                    return;
                }

                var target = this.checklists.find(function (entry) {
                    return String(entry.id) === previousId;
                }) || this.checklists[0];

                if (!this.selectedChecklist || String(this.selectedChecklist.id) !== String(target.id)) {
                    await this.selectChecklist(target, true);
                }
            },
            refreshSettings: async function () {
                var results = await Promise.all([
                    this.requestJSON({ path: '/api/getTeachingStatus', method: 'GET', sessionHeader: true }),
                    this.requestJSON({ path: '/api/getImageStorageLimit', method: 'GET', sessionHeader: true })
                ]);

                this.settingsForm.teachingEnabled = String(results[0].teaching) === '1';
                this.settingsForm.imageLimitMb = Math.max(1, Math.round((Number(results[1].limit || 0) || 0) / 1024 / 1024));
            },
            refreshSystemStatus: async function () {
                var data = await this.requestSystemStatus();
                this.systemStatus = data.status || null;
            },
            selectTab: function (tab) {
                this.ui.activeTab = tab;
            },
            openMoreTab: function (tab) {
                this.ui.activeTab = 'more';
                this.ui.moreTab = tab;
            },
            openQuickCreate: function () {
                if (this.ui.activeTab === 'cycles') {
                    this.openCycleDialog();
                    return;
                }
                if (this.ui.activeTab === 'courses') {
                    this.openCourseDialog();
                    return;
                }
                if (this.ui.activeTab === 'more') {
                    if (this.ui.moreTab === 'projects') {
                        this.openProjectDialog();
                        return;
                    }
                    if (this.ui.moreTab === 'checklists') {
                        this.openChecklistDialog();
                        return;
                    }
                    if (this.ui.moreTab === 'renewals') {
                        this.openRenewalDialog();
                        return;
                    }
                    if (this.ui.moreTab === 'categories') {
                        this.openCategoryDialog();
                        return;
                    }
                }
                this.openItemDialog();
            },
            tagStyle: function (color) {
                var fill = color || '#1ea7a8';
                return {
                    backgroundColor: fill,
                    borderColor: fill,
                    color: '#ffffff'
                };
            },
            itemCategoryTags: function (item) {
                var ids = parseCategoryArray(item && item.category);
                return this.categories.filter(function (category) {
                    return ids.indexOf(Number(category.id)) > -1;
                });
            },
            renewalCategoryName: function (categoryId) {
                var match = this.renewalCategories.find(function (category) {
                    return String(category.id) === String(categoryId);
                });
                return match ? match.name : '未分类';
            },
            renewalTagType: function (renewal) {
                var remaining = daysUntil(renewal.expiry_date);
                if (remaining < 0) {
                    return 'danger';
                }
                if (remaining === 0) {
                    return 'warning';
                }
                if (remaining <= Number(renewal.reminder_days || 0)) {
                    return 'primary';
                }
                return 'success';
            },
            renewalCountdownLabel: function (renewal) {
                var remaining = daysUntil(renewal.expiry_date);
                if (remaining < 0) {
                    return '已过期 ' + Math.abs(remaining) + ' 天';
                }
                if (remaining === 0) {
                    return '今天到期';
                }
                return remaining + ' 天后到期';
            },
            describeCycle: function (cycle) {
                var payload = parseCyclePayload(cycle && cycle.cycle);
                if (payload.type === 'daily') {
                    return '每日';
                }
                if (payload.type === 'weekly') {
                    var weeklyConfig = parseJSON(payload.configText, { day: '' });
                    var labels = String(weeklyConfig.day || '')
                        .split(',')
                        .filter(function (entry) { return entry !== ''; })
                        .map(function (entry) {
                            var match = COURSE_DAY_OPTIONS.find(function (day) {
                                return String(day.value) === String(entry);
                            });
                            return match ? match.label : entry;
                        });
                    return labels.length ? '每周 ' + labels.join(' / ') : '每周';
                }
                if (payload.type === 'monthly') {
                    var monthlyConfig = parseJSON(payload.configText, { day: 1 });
                    return '每月 ' + Number(monthlyConfig.day || 1) + ' 日';
                }
                if (payload.type === 'monthly_last') {
                    var lastConfig = parseJSON(payload.configText, { day: 1 });
                    return '每月倒数第 ' + Number(lastConfig.day || 1) + ' 天';
                }
                return '未知循环';
            },
            saveSettings: async function () {
                try {
                    await Promise.all([
                        this.requestJSON({
                            path: '/api/setTeachingStatus',
                            method: 'POST',
                            sessionBody: true,
                            body: { teaching: this.settingsForm.teachingEnabled ? '1' : '0' }
                        }),
                        this.requestJSON({
                            path: '/api/setImageStorageLimit',
                            method: 'POST',
                            sessionBody: true,
                            body: { limit: Number(this.settingsForm.imageLimitMb || 0) * 1024 * 1024 }
                        })
                    ]);
                    ElMessage.success('设置已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存设置失败');
                }
            },
            openItemDialog: function (item) {
                this.editors.itemId = item ? String(item.id) : '';
                this.drafts.item = item ? {
                    title: item.title || '',
                    description: item.description || '',
                    deadline: item.deadline || '',
                    plannedTime: item.planned_time || '',
                    category: parseCategoryArray(item.category)
                } : defaultItemDraft();
                this.dialogs.item = true;
            },
            submitItem: async function () {
                if (!String(this.drafts.item.title || '').trim()) {
                    ElMessage.warning('事项标题不能为空');
                    return;
                }

                try {
                    if (this.editors.itemId) {
                        await this.requestJSON({
                            path: '/api/updateItem',
                            method: 'POST',
                            sessionBody: true,
                            body: {
                                id: this.editors.itemId,
                                title: this.drafts.item.title,
                                description: this.drafts.item.description,
                                deadline: this.drafts.item.deadline || null,
                                planned_time: this.drafts.item.plannedTime || null,
                                category: this.drafts.item.category
                            }
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createItem',
                            method: 'POST',
                            sessionBody: true,
                            body: {
                                title: this.drafts.item.title,
                                description: this.drafts.item.description,
                                deadline: this.drafts.item.deadline || null,
                                plannedTime: this.drafts.item.plannedTime || null,
                                category: this.drafts.item.category
                            }
                        });
                    }

                    this.dialogs.item = false;
                    await this.refreshItems();
                    ElMessage.success('事项已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存事项失败');
                }
            },
            setItemDone: async function (item, done) {
                try {
                    await this.requestJSON({
                        path: done ? '/api/markItemAsDone' : '/api/markItemAsUndone',
                        method: 'POST',
                        sessionBody: true,
                        body: { id: item.id }
                    });
                    await this.refreshItems();
                    ElMessage.success(done ? '已标记为完成' : '已恢复为未完成');
                } catch (error) {
                    ElMessage.error(error.message || '更新事项状态失败');
                }
            },
            deleteItem: async function (item) {
                try {
                    await ElMessageBox.confirm('删除后事项会从待办列表中移除。', '删除事项', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteItem',
                        method: 'POST',
                        sessionBody: true,
                        body: { id: item.id }
                    });
                    await this.refreshItems();
                    ElMessage.success('事项已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除事项失败');
                }
            },
            openCategoryDialog: function (category) {
                this.editors.categoryId = category ? String(category.id) : '';
                this.drafts.category = category ? {
                    name: category.name || '',
                    color: category.color || '#1ea7a8',
                    note: category.note || ''
                } : defaultCategoryDraft();
                this.dialogs.category = true;
            },
            submitCategory: async function () {
                if (!String(this.drafts.category.name || '').trim()) {
                    ElMessage.warning('分类名称不能为空');
                    return;
                }
                if (!String(this.drafts.category.note || '').trim()) {
                    ElMessage.warning('分类说明不能为空');
                    return;
                }

                try {
                    if (this.editors.categoryId) {
                        await this.requestJSON({
                            path: '/api/updateCategory/' + encodeURIComponent(this.editors.categoryId),
                            method: 'PUT',
                            sessionBody: true,
                            body: {
                                name: this.drafts.category.name,
                                color: this.drafts.category.color,
                                note: this.drafts.category.note,
                                metadata: null
                            }
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createCategory',
                            method: 'POST',
                            sessionBody: true,
                            body: {
                                name: this.drafts.category.name,
                                color: this.drafts.category.color,
                                note: this.drafts.category.note,
                                metadata: null
                            }
                        });
                    }

                    this.dialogs.category = false;
                    await this.refreshCategories();
                    ElMessage.success('分类已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存分类失败');
                }
            },
            deleteCategory: async function (category) {
                try {
                    await ElMessageBox.confirm('删除分类前，请先确保没有事项仍在使用它。', '删除分类', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteCategory',
                        method: 'POST',
                        sessionBody: true,
                        body: { id: category.id }
                    });
                    await this.refreshCategories();
                    ElMessage.success('分类已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除分类失败');
                }
            },
            openCycleDialog: function (cycle) {
                this.editors.cycleId = cycle ? String(cycle.id) : '';

                if (!cycle) {
                    this.drafts.cycle = defaultCycleDraft();
                    this.drafts.cycle.next = formatDateTimeForPicker(new Date());
                    this.dialogs.cycle = true;
                    return;
                }

                var payload = parseCyclePayload(cycle.cycle);
                var config = parseJSON(payload.configText, {});
                this.drafts.cycle = {
                    name: cycle.name || '',
                    note: cycle.note || '',
                    next: cycle.next ? String(cycle.next).replace('T', ' ').slice(0, 19) : '',
                    type: payload.type,
                    weekDays: payload.type === 'weekly' && config.day ? String(config.day).split(',').filter(Boolean).map(function (entry) { return Number(entry); }) : [],
                    monthDay: Number(config.day || 1),
                    monthLastOffset: Number(config.day || 1)
                };
                this.dialogs.cycle = true;
            },
            cycleConfigText: function () {
                if (this.drafts.cycle.type === 'weekly') {
                    return JSON.stringify({ day: ensureArray(this.drafts.cycle.weekDays).join(',') });
                }
                if (this.drafts.cycle.type === 'monthly') {
                    return JSON.stringify({ day: Number(this.drafts.cycle.monthDay || 1) });
                }
                if (this.drafts.cycle.type === 'monthly_last') {
                    return JSON.stringify({ day: Number(this.drafts.cycle.monthLastOffset || 1) });
                }
                return JSON.stringify({});
            },
            submitCycle: async function () {
                if (!String(this.drafts.cycle.name || '').trim()) {
                    ElMessage.warning('循环名称不能为空');
                    return;
                }
                if (!String(this.drafts.cycle.next || '').trim()) {
                    ElMessage.warning('请选择下次执行时间');
                    return;
                }
                if (this.drafts.cycle.type === 'weekly' && !ensureArray(this.drafts.cycle.weekDays).length) {
                    ElMessage.warning('请选择至少一个星期');
                    return;
                }

                var body = {
                    name: this.drafts.cycle.name,
                    note: this.drafts.cycle.note,
                    cycle: this.drafts.cycle.type,
                    next: this.drafts.cycle.next.replace(' ', 'T'),
                    config: this.cycleConfigText()
                };

                try {
                    if (this.editors.cycleId) {
                        body.id = this.editors.cycleId;
                        await this.requestJSON({ path: '/api/updateCycle', method: 'POST', sessionBody: true, body: body });
                    } else {
                        await this.requestJSON({ path: '/api/createCycle', method: 'POST', sessionBody: true, body: body });
                    }
                    this.dialogs.cycle = false;
                    await this.refreshCycles();
                    ElMessage.success('循环已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存循环失败');
                }
            },
            delayCycle: async function (cycle) {
                try {
                    await this.requestJSON({
                        path: '/api/delayCycleNextDate',
                        method: 'POST',
                        sessionBody: true,
                        body: { id: cycle.id }
                    });
                    await this.refreshCycles();
                    ElMessage.success('已推迟一天');
                } catch (error) {
                    ElMessage.error(error.message || '推迟循环失败');
                }
            },
            deleteCycle: async function (cycle) {
                try {
                    await ElMessageBox.confirm('删除后循环记录会从列表中移除。', '删除循环', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteCycle',
                        method: 'POST',
                        sessionBody: true,
                        body: { id: cycle.id }
                    });
                    await this.refreshCycles();
                    ElMessage.success('循环已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除循环失败');
                }
            },
            openCourseDialog: function (course) {
                this.editors.courseId = course ? String(course.id) : '';
                this.drafts.course = course ? {
                    id: String(course.id || ''),
                    course_name: course.course_name || '',
                    course_code: course.course_code || '',
                    venue: course.venue || '',
                    instructor_name: course.instructor_name || '',
                    day: Number(course.day),
                    course_color: course.course_color || '#1ea7a8',
                    start_time: course.start_time || '09:00:00',
                    end_time: course.end_time || '10:00:00',
                    is_active: !!course.is_active
                } : defaultCourseDraft();
                this.dialogs.course = true;
            },
            submitCourse: async function () {
                if (!String(this.drafts.course.course_name || '').trim()) {
                    ElMessage.warning('课程名称不能为空');
                    return;
                }
                if (!String(this.drafts.course.course_code || '').trim()) {
                    ElMessage.warning('课程代码不能为空');
                    return;
                }

                var body = {
                    course_code: this.drafts.course.course_code,
                    course_color: this.drafts.course.course_color,
                    course_name: this.drafts.course.course_name,
                    venue: this.drafts.course.venue,
                    start_time: this.drafts.course.start_time,
                    end_time: this.drafts.course.end_time,
                    instructor_name: this.drafts.course.instructor_name,
                    is_active: !!this.drafts.course.is_active,
                    day: Number(this.drafts.course.day)
                };

                if (this.editors.courseId) {
                    body.id = this.editors.courseId;
                }

                try {
                    await this.requestJSON({ path: '/api/addOrUpdateCourse', method: 'POST', sessionBody: true, body: body });
                    this.dialogs.course = false;
                    await this.refreshCourses();
                    ElMessage.success('课程已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存课程失败');
                }
            },
            deleteCourse: async function (course) {
                try {
                    await ElMessageBox.confirm('确定删除这门课程吗？', '删除课程', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteCourse',
                        method: 'POST',
                        sessionBody: true,
                        body: { id: course.id }
                    });
                    this.dialogs.course = false;
                    await this.refreshCourses();
                    ElMessage.success('课程已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除课程失败');
                }
            },
            openProjectDialog: function (project) {
                this.editors.projectId = project ? String(project.id) : '';
                this.drafts.project = project ? {
                    name: project.name || '',
                    description: project.description || '',
                    color: project.color || '#1ea7a8'
                } : defaultProjectDraft();
                this.dialogs.project = true;
            },
            submitProject: async function () {
                if (!String(this.drafts.project.name || '').trim()) {
                    ElMessage.warning('项目名称不能为空');
                    return;
                }

                try {
                    if (this.editors.projectId) {
                        await this.requestJSON({
                            path: '/api/updateProject/' + encodeURIComponent(this.editors.projectId),
                            method: 'PUT',
                            sessionBody: true,
                            body: {
                                name: this.drafts.project.name,
                                description: this.drafts.project.description,
                                color: this.drafts.project.color
                            }
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createProject',
                            method: 'POST',
                            sessionBody: true,
                            body: {
                                name: this.drafts.project.name,
                                description: this.drafts.project.description,
                                color: this.drafts.project.color
                            }
                        });
                    }

                    this.dialogs.project = false;
                    await this.refreshProjects();
                    ElMessage.success('项目已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存项目失败');
                }
            },
            recordProject: async function (project) {
                try {
                    await this.requestJSON({
                        path: '/api/participateInProject',
                        method: 'POST',
                        sessionBody: true,
                        body: { projectId: project.id }
                    });
                    ElMessage.success('已记录一次参与');
                    if (this.selectedProject && String(this.selectedProject.id) === String(project.id) && this.ui.projectRecordsVisible) {
                        await this.openProjectRecords(project);
                    }
                } catch (error) {
                    ElMessage.error(error.message || '记录参与失败');
                }
            },
            openProjectRecords: async function (project) {
                try {
                    var data = await this.requestJSON({
                        path: '/api/getProjectRecords/' + encodeURIComponent(project.id),
                        method: 'GET',
                        sessionHeader: true
                    });
                    this.selectedProject = project;
                    this.projectRecords = ensureArray(data.records);
                    this.ui.projectRecordsVisible = true;
                } catch (error) {
                    ElMessage.error(error.message || '加载项目记录失败');
                }
            },
            deleteProject: async function (project) {
                try {
                    await ElMessageBox.confirm('删除后项目会从活动列表中移除。', '删除项目', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteProject/' + encodeURIComponent(project.id),
                        method: 'DELETE',
                        sessionBody: true,
                        body: {}
                    });
                    await this.refreshProjects();
                    ElMessage.success('项目已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除项目失败');
                }
            },
            openRenewalDialog: function (renewal) {
                this.editors.renewalId = renewal ? String(renewal.id) : '';
                this.drafts.renewal = renewal ? {
                    name: renewal.name || '',
                    description: renewal.description || '',
                    categoryId: renewal.category_id || '',
                    expiryDate: renewal.expiry_date ? String(renewal.expiry_date).slice(0, 10) : formatDateForPicker(new Date()),
                    reminderDays: Number(renewal.reminder_days || 0)
                } : defaultRenewalDraft();
                this.dialogs.renewal = true;
            },
            submitRenewal: async function () {
                if (!String(this.drafts.renewal.name || '').trim()) {
                    ElMessage.warning('续费名称不能为空');
                    return;
                }
                if (!this.drafts.renewal.categoryId) {
                    ElMessage.warning('请选择续费分类');
                    return;
                }

                var body = {
                    name: this.drafts.renewal.name,
                    description: this.drafts.renewal.description,
                    categoryId: this.drafts.renewal.categoryId,
                    expiryDate: this.drafts.renewal.expiryDate,
                    reminderDays: Number(this.drafts.renewal.reminderDays || 0)
                };

                try {
                    if (this.editors.renewalId) {
                        await this.requestJSON({
                            path: '/api/updateRenewals/' + encodeURIComponent(this.editors.renewalId),
                            method: 'PUT',
                            sessionBody: true,
                            body: body
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createRenewals',
                            method: 'POST',
                            sessionBody: true,
                            body: body
                        });
                    }
                    this.dialogs.renewal = false;
                    await this.refreshRenewals();
                    ElMessage.success('续费项目已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存续费项目失败');
                }
            },
            deleteRenewal: async function (renewal) {
                try {
                    await ElMessageBox.confirm('确定删除这个续费项目吗？', '删除续费', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteRenewals/' + encodeURIComponent(renewal.id),
                        method: 'DELETE',
                        sessionBody: true,
                        body: {}
                    });
                    await this.refreshRenewals();
                    ElMessage.success('续费项目已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除续费项目失败');
                }
            },
            openChecklistDialog: function (checklist) {
                this.editors.checklistId = checklist ? String(checklist.id) : '';
                this.drafts.checklist = checklist ? {
                    name: checklist.name || '',
                    orderIndex: Number(checklist.order_index || 0)
                } : {
                    name: '',
                    orderIndex: nextOrderIndex(this.checklists, 'order_index')
                };
                this.dialogs.checklist = true;
            },
            submitChecklist: async function () {
                if (!String(this.drafts.checklist.name || '').trim()) {
                    ElMessage.warning('检查表名称不能为空');
                    return;
                }

                var body = {
                    name: this.drafts.checklist.name,
                    orderIndex: Number(this.drafts.checklist.orderIndex || 0)
                };

                try {
                    if (this.editors.checklistId) {
                        await this.requestJSON({
                            path: '/api/updateChecklist/' + encodeURIComponent(this.editors.checklistId),
                            method: 'PUT',
                            sessionBody: true,
                            body: body
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createChecklist',
                            method: 'POST',
                            sessionBody: true,
                            body: body
                        });
                    }

                    this.dialogs.checklist = false;
                    await this.refreshChecklists();
                    ElMessage.success('检查表已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存检查表失败');
                }
            },
            deleteChecklist: async function (checklist) {
                try {
                    await ElMessageBox.confirm('删除后会同时删除其下所有检查项。', '删除检查表', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteChecklist/' + encodeURIComponent(checklist.id),
                        method: 'DELETE',
                        sessionBody: true,
                        body: {}
                    });
                    await this.refreshChecklists();
                    ElMessage.success('检查表已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除检查表失败');
                }
            },
            selectChecklist: async function (checklist, silent) {
                try {
                    var data = await this.requestJSON({
                        path: '/api/getChecklist/' + encodeURIComponent(checklist.id),
                        method: 'GET',
                        sessionHeader: true
                    });
                    this.selectedChecklist = data.checklist || null;
                } catch (error) {
                    if (!silent) {
                        ElMessage.error(error.message || '加载检查表详情失败');
                    }
                }
            },
            openChecklistItemDialog: function (item) {
                if (!this.selectedChecklist) {
                    ElMessage.warning('请先选择检查表');
                    return;
                }

                this.editors.checklistItemId = item ? String(item.id) : '';
                this.drafts.checklistItem = item ? {
                    name: item.name || '',
                    orderIndex: Number(item.order_index || 0),
                    checked: !!item.checked
                } : {
                    name: '',
                    orderIndex: nextOrderIndex(this.selectedChecklist.items || [], 'order_index'),
                    checked: false
                };
                this.dialogs.checklistItem = true;
            },
            submitChecklistItem: async function () {
                if (!this.selectedChecklist) {
                    ElMessage.warning('请先选择检查表');
                    return;
                }
                if (!String(this.drafts.checklistItem.name || '').trim()) {
                    ElMessage.warning('检查项名称不能为空');
                    return;
                }

                var body = {
                    name: this.drafts.checklistItem.name,
                    orderIndex: Number(this.drafts.checklistItem.orderIndex || 0)
                };

                try {
                    if (this.editors.checklistItemId) {
                        await this.requestJSON({
                            path: '/api/updateChecklistItem/' + encodeURIComponent(this.editors.checklistItemId),
                            method: 'PUT',
                            sessionBody: true,
                            body: {
                                name: body.name,
                                orderIndex: body.orderIndex,
                                checked: this.drafts.checklistItem.checked ? 1 : 0
                            }
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createChecklistItem',
                            method: 'POST',
                            sessionBody: true,
                            body: {
                                checklistId: this.selectedChecklist.id,
                                name: body.name,
                                orderIndex: body.orderIndex
                            }
                        });
                    }

                    this.dialogs.checklistItem = false;
                    await this.selectChecklist(this.selectedChecklist, true);
                    await this.refreshChecklists();
                    ElMessage.success('检查项已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存检查项失败');
                }
            },
            toggleChecklistItem: async function (item, checked) {
                try {
                    await this.requestJSON({
                        path: '/api/updateChecklistItemStatus',
                        method: 'POST',
                        sessionBody: true,
                        body: {
                            id: item.id,
                            checked: checked ? 1 : 0
                        }
                    });
                    item.checked = checked ? 1 : 0;
                } catch (error) {
                    ElMessage.error(error.message || '更新检查项状态失败');
                }
            },
            deleteChecklistItem: async function (item) {
                try {
                    await ElMessageBox.confirm('确定删除这个检查项吗？', '删除检查项', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteChecklistItem/' + encodeURIComponent(item.id),
                        method: 'DELETE',
                        sessionBody: true,
                        body: {}
                    });
                    await this.selectChecklist(this.selectedChecklist, true);
                    await this.refreshChecklists();
                    ElMessage.success('检查项已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除检查项失败');
                }
            },
            clearChecklistProgress: async function () {
                if (!this.selectedChecklist || !Array.isArray(this.selectedChecklist.items) || !this.selectedChecklist.items.length) {
                    return;
                }

                try {
                    await ElMessageBox.confirm('这会取消当前检查表的所有勾选状态。', '清空勾选', {
                        type: 'warning',
                        confirmButtonText: '清空',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    var updates = this.selectedChecklist.items.map(function (item) {
                        return this.requestJSON({
                            path: '/api/updateChecklistItemStatus',
                            method: 'POST',
                            sessionBody: true,
                            body: {
                                id: item.id,
                                checked: 0
                            }
                        });
                    }, this);

                    await Promise.all(updates);
                    await this.selectChecklist(this.selectedChecklist, true);
                    ElMessage.success('已清空勾选');
                } catch (error) {
                    ElMessage.error(error.message || '清空勾选失败');
                }
            },
            resetRenewalCategoryDraft: function () {
                this.editors.renewalCategoryId = '';
                this.drafts.renewalCategory = defaultRenewalCategoryDraft();
            },
            editRenewalCategory: function (category) {
                this.editors.renewalCategoryId = String(category.id || '');
                this.drafts.renewalCategory = {
                    name: category.name || '',
                    color: category.color || '#1ea7a8',
                    description: category.note || category.description || ''
                };
            },
            submitRenewalCategory: async function () {
                if (!String(this.drafts.renewalCategory.name || '').trim()) {
                    ElMessage.warning('续费分类名称不能为空');
                    return;
                }

                var body = {
                    name: this.drafts.renewalCategory.name,
                    color: this.drafts.renewalCategory.color,
                    description: this.drafts.renewalCategory.description
                };

                try {
                    if (this.editors.renewalCategoryId) {
                        await this.requestJSON({
                            path: '/api/updateRenewalCategories/' + encodeURIComponent(this.editors.renewalCategoryId),
                            method: 'PUT',
                            sessionBody: true,
                            body: body
                        });
                    } else {
                        await this.requestJSON({
                            path: '/api/createRenewalCategories',
                            method: 'POST',
                            sessionBody: true,
                            body: body
                        });
                    }

                    this.resetRenewalCategoryDraft();
                    await this.refreshRenewals();
                    ElMessage.success('续费分类已保存');
                } catch (error) {
                    ElMessage.error(error.message || '保存续费分类失败');
                }
            },
            deleteRenewalCategory: async function (category) {
                try {
                    await ElMessageBox.confirm('确定删除这个续费分类吗？', '删除续费分类', {
                        type: 'warning',
                        confirmButtonText: '删除',
                        cancelButtonText: '取消'
                    });
                } catch (error) {
                    return;
                }

                try {
                    await this.requestJSON({
                        path: '/api/deleteRenewalCategories/' + encodeURIComponent(category.id),
                        method: 'POST',
                        sessionBody: true,
                        body: {}
                    });
                    this.resetRenewalCategoryDraft();
                    await this.refreshRenewals();
                    ElMessage.success('续费分类已删除');
                } catch (error) {
                    ElMessage.error(error.message || '删除续费分类失败');
                }
            }
        },
        mounted: function () {
            this.bootstrap();
        }
    });

    Object.keys(ElementPlusIconsVue).forEach(function (name) {
        app.component(name, ElementPlusIconsVue[name]);
    });

    app.use(ElementPlus);
    app.mount('#app');
})();
// Box3.setFromBufferAttribute reference cases; see lib/buffer_readers.mjs.

import { any } from '../lib/buffer_readers.mjs';

export default {
	name: 'Box3',
	type: 'Box3',
	fixture: 'Box3FromBufferAttribute',
	cases: 24,
	methods: [ { name: 'setFromBufferAttribute', args: [ any ] } ]
};

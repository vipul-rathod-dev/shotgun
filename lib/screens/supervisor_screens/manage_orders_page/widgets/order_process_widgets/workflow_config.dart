const workflow = [
  {
    'key': 'raw_material',
    'title': 'Raw Material',
    'inputs': [],
    'outputs': ['color'],
  },
  {
    'key': 'color',
    'title': 'Color Process',
    'inputs': ['raw_material'],
    'outputs': ['qc'],
  },
  {
    'key': 'qc',
    'title': 'QC Process',
    'inputs': ['color'],
    'outputs': ['fitting'],
  },
  {
    'key': 'fitting',
    'title': 'Fitting Process',
    'inputs': ['qc'],
    'outputs': ['demo'],
  },
  {
    'key': 'demo',
    'title': 'Demo Process',
    'inputs': ['fitting'],
    'outputs': ['packing'],
  },
  {
    'key': 'packing',
    'title': 'Packing Process',
    'inputs': ['demo'],
    'outputs': [],
  },
];

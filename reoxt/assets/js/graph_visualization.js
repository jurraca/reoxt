
// Graph visualization hook for Phoenix LiveView
const GraphVisualization = {
  mounted() {
    console.log('GraphVisualization hook mounted');
    console.log('Container element:', this.el);
    
    // Wait for D3 to be available
    this.waitForD3(() => {
      this.initializeGraph();
    });

    // Listen for graph data updates from LiveView
    this.handleEvent("render_graph", (data) => {
      console.log('Received render_graph event:', data);
      this.renderGraph(data.graph_data);
    });

    this.handleEvent("clear_graph", () => {
      this.clearGraph();
    });

    this.handleEvent("reset_graph", () => {
      this.resetGraph();
    });
  },

  waitForD3(callback) {
    if (typeof d3 !== 'undefined') {
      callback();
    } else {
      // Load D3.js if not already available
      const script = document.createElement('script');
      script.src = 'https://d3js.org/d3.v7.min.js';
      script.onload = () => {
        console.log('D3.js loaded');
        callback();
      };
      script.onerror = () => {
        console.error('Failed to load D3.js');
      };
      document.head.appendChild(script);
    }
  },

  initializeGraph() {
    console.log('Initializing graph...');
    // Set up the SVG container
    const container = this.el;
    const width = container.clientWidth || 800; // Fallback width
    const height = container.clientHeight || 600; // Fallback height

    console.log('Container dimensions:', { width, height });

    // Clear any existing content
    container.innerHTML = '';

    // Create SVG element
    this.svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .style("background", "linear-gradient(145deg, #0a0a0a 0%, #1a1a1a 100%)")
      .style("border-radius", "8px");

    // Create groups for different elements
    this.linkGroup = this.svg.append("g").attr("class", "links");
    this.nodeGroup = this.svg.append("g").attr("class", "nodes");

    // Initialize zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => {
        this.linkGroup.attr("transform", event.transform);
        this.nodeGroup.attr("transform", event.transform);
      });

    this.svg.call(zoom);

    // Set up force simulation
    this.simulation = d3.forceSimulation()
      .force("link", d3.forceLink().id(d => d.txid).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(30));

    // Store dimensions for later use
    this.width = width;
    this.height = height;

    console.log('Graph initialization complete');
  },

  renderGraph(graphData) {
    if (!graphData || !graphData.nodes || !graphData.edges) {
      console.error("Invalid graph data provided");
      return;
    }

    if (!this.svg) {
      console.error("SVG not initialized, reinitializing...");
      this.initializeGraph();
    }

    // Store current height for confirmations calculation
    this.currentHeight = graphData.current_height || 800000;

    console.log("Rendering graph with data:", graphData);
    console.log("Number of nodes:", graphData.nodes.length);
    console.log("Number of edges:", graphData.edges.length);

    // Initialize or update the graph dataset
    if (!this.graphNodes) {
      this.graphNodes = new Map();
    }
    if (!this.graphLinks) {
      this.graphLinks = new Map();
    }

    // Process and merge new nodes with existing ones
    const newNodes = graphData.nodes.map(node => {
      const existingNode = this.graphNodes.get(node.txid);
      if (existingNode) {
        // Update existing node data but preserve position if it exists
        return {
          ...existingNode,
          ...node,
          id: node.txid,
          // Keep existing position if available, otherwise random
          x: existingNode.x !== undefined ? existingNode.x : Math.random() * (this.width || 800),
          y: existingNode.y !== undefined ? existingNode.y : Math.random() * (this.height || 600)
        };
      } else {
        // New node with random initial position
        return {
          ...node,
          id: node.txid,
          x: Math.random() * (this.width || 800),
          y: Math.random() * (this.height || 600)
        };
      }
    });

    // Update the nodes map
    newNodes.forEach(node => {
      this.graphNodes.set(node.id, node);
    });

    // Process and merge new links
    const newLinks = graphData.edges.map(edge => {
      const linkId = `${edge.from}-${edge.to}`;
      const existingLink = this.graphLinks.get(linkId);
      if (existingLink) {
        return {
          ...existingLink,
          source: edge.from,
          target: edge.to,
          value: edge.value || 1
        };
      } else {
        return {
          source: edge.from,
          target: edge.to,
          value: edge.value || 1
        };
      }
    });

    // Update the links map
    newLinks.forEach(link => {
      const linkId = `${link.source}-${link.target}`;
      this.graphLinks.set(linkId, link);
    });

    // Convert maps to arrays for D3
    const nodes = Array.from(this.graphNodes.values());
    const links = Array.from(this.graphLinks.values());

    console.log("Total nodes in dataset:", nodes.length);
    console.log("Total links in dataset:", links.length);

    // Update links with proper enter/update/exit pattern
    const linkSelection = this.linkGroup
      .selectAll("line")
      .data(links, d => `${d.source.id || d.source}-${d.target.id || d.target}`);

    // Remove old links
    linkSelection.exit().remove();

    // Add new links
    const linkEnter = linkSelection.enter()
      .append("line")
      .attr("stroke", "#39ff14")
      .attr("stroke-opacity", 0.7)
      .attr("stroke-width", d => Math.max(Math.sqrt(d.value) || 1, 2))
      .style("filter", "drop-shadow(0 0 4px #39ff14)");

    // Update existing links
    const linkUpdate = linkEnter.merge(linkSelection)
      .attr("stroke-width", d => Math.max(Math.sqrt(d.value) || 1, 2));

    // Update nodes with proper enter/update/exit pattern
    const nodeSelection = this.nodeGroup
      .selectAll("g")
      .data(nodes, d => d.id);

    // Remove old nodes
    nodeSelection.exit().remove();

    // Add new nodes
    const nodeEnter = nodeSelection.enter()
      .append("g")
      .attr("class", "node")
      .call(this.drag(this.simulation));

    console.log("Created new node groups:", nodeEnter.size());

    // Add circles for new nodes
    nodeEnter.append("circle")
      .attr("r", d => this.getNodeRadius(d))
      .attr("fill", d => this.getNodeColor(d))
      .attr("stroke", d => this.getNodeStrokeColor(d))
      .attr("stroke-width", 3)
      .style("filter", d => `drop-shadow(0 0 8px ${this.getNodeColor(d)})`);

    // Add labels for new nodes
    nodeEnter.append("text")
      .attr("dx", 12)
      .attr("dy", ".35em")
      .style("font-size", "11px")
      .style("fill", "#e5e5e5")
      .style("font-weight", "500")
      .style("text-shadow", "0 0 4px rgba(57, 255, 20, 0.3)")
      .text(d => d.txid.substring(0, 8) + "...");

    // Add tooltips for new nodes
    nodeEnter.append("title")
      .text(d => `TX: ${d.txid}\nValue: ${this.formatValue(d.total_output_value || 0)} BTC\nConfirmations: ${this.getConfirmations(d)}`);

    // Update existing nodes
    const nodeUpdate = nodeEnter.merge(nodeSelection);

    // Update circles for all nodes (new and existing)
    nodeUpdate.select("circle")
      .attr("r", d => this.getNodeRadius(d))
      .attr("fill", d => this.getNodeColor(d))
      .attr("stroke", d => this.getNodeStrokeColor(d));

    // Update tooltips for all nodes
    nodeUpdate.select("title")
      .text(d => `TX: ${d.txid}\nValue: ${this.formatValue(d.total_output_value || 0)} BTC\nConfirmations: ${this.getConfirmations(d)}`);

    console.log("Total active nodes:", nodeUpdate.size());

    // Update simulation with new data
    this.simulation
      .nodes(nodes)
      .on("tick", () => {
        linkUpdate
          .attr("x1", d => {
            const source = d.source.id ? d.source : nodes.find(n => n.id === d.source);
            return source ? source.x : 0;
          })
          .attr("y1", d => {
            const source = d.source.id ? d.source : nodes.find(n => n.id === d.source);
            return source ? source.y : 0;
          })
          .attr("x2", d => {
            const target = d.target.id ? d.target : nodes.find(n => n.id === d.target);
            return target ? target.x : 0;
          })
          .attr("y2", d => {
            const target = d.target.id ? d.target : nodes.find(n => n.id === d.target);
            return target ? target.y : 0;
          });

        nodeUpdate
          .attr("transform", d => `translate(${d.x},${d.y})`);
      });

    // Update forces
    this.simulation
      .force("center", d3.forceCenter((this.width || 800) / 2, (this.height || 600) / 2))
      .force("link").links(links);

    console.log("Starting simulation with", nodes.length, "nodes and", links.length, "links");
    this.simulation.alpha(0.3).restart(); // Use lower alpha for smoother updates
  },

  getNodeRadius(node) {
    // Scale radius based on transaction value
    const baseRadius = 8;
    const value = node.total_output_value || 0;

    if (value > 100000000) { // > 1 BTC
      return baseRadius * 2;
    } else if (value > 10000000) { // > 0.1 BTC
      return baseRadius * 1.5;
    }
    return baseRadius;
  },

  getNodeColor(node) {
    // Color based on confirmations and value with neon theme
    const confirmations = this.getConfirmations(node);
    const value = node.total_output_value || 0;

    if (confirmations === 0) {
      return "#ff1493"; // Neon pink for unconfirmed
    } else if (value > 100000000) { // > 1 BTC
      return "#39ff14"; // Neon green for high value
    } else if (confirmations < 6) {
      return "#00ffff"; // Neon cyan for low confirmations
    }
    return "#bf00ff"; // Neon purple for normal transactions
  },

  getNodeStrokeColor(node) {
    // Matching stroke colors with higher opacity
    const confirmations = this.getConfirmations(node);
    const value = node.total_output_value || 0;

    if (confirmations === 0) {
      return "#ff69b4"; // Lighter pink stroke
    } else if (value > 100000000) {
      return "#7fff00"; // Lighter green stroke
    } else if (confirmations < 6) {
      return "#87ceeb"; // Lighter cyan stroke
    }
    return "#da70d6"; // Lighter purple stroke
  },

  getConfirmations(node) {
    // Calculate confirmations based on block_height
    if (this.currentHeight && node.block_height) {
      return this.currentHeight - node.block_height;
    }
    return 0; // Default to 0 if calculation is not possible
  },

  formatValue(satoshis) {
    return (satoshis / 100000000).toFixed(8);
  },

  clearGraph() {
    if (this.simulation) {
      this.simulation.stop();
    }

    if (this.linkGroup) {
      this.linkGroup.selectAll("*").remove();
    }
    if (this.nodeGroup) {
      this.nodeGroup.selectAll("*").remove();
    }
  },

  clearDataset() {
    // Clear the internal data maps
    if (this.graphNodes) {
      this.graphNodes.clear();
    }
    if (this.graphLinks) {
      this.graphLinks.clear();
    }
  },

  resetGraph() {
    // Clear both visual elements and dataset
    this.clearGraph();
    this.clearDataset();
  },

  drag(simulation) {
    function dragstarted(event, d) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      d.fx = d.x;
      d.fy = d.y;
    }

    function dragged(event, d) {
      d.fx = event.x;
      d.fy = event.y;
    }

    function dragended(event, d) {
      if (!event.active) simulation.alphaTarget(0);
      d.fx = null;
      d.fy = null;
    }

    return d3.drag()
      .on("start", dragstarted)
      .on("drag", dragged)
      .on("end", dragended);
  },

  destroyed() {
    if (this.simulation) {
      this.simulation.stop();
    }
  }
};

export default GraphVisualization;

import traceback

import dataiku
from dash import Dash, dcc, html, Input, Output, State
from dash.exceptions import PreventUpdate
from dataiku.llm.python import BaseLLM
from langchain_core.messages import ToolMessage, SystemMessage
from langchain_core.tools import tool

app.layout = html.Div([
    html.H1("🎾 ATP Insights Agent", style={"textAlign": "center", "marginBottom": "20px", "color": "#333"}),
    dcc.Store(id='messages', data=[]),
    html.Div([
        html.Label("Ask your question", htmlFor="search_input", style={"marginRight": "10px", "fontWeight": "bold", "minWidth": "150px"}),
        html.Div([
            dcc.Input(id="search_input", placeholder="What can I do for you?", type="text", style={
                "width": "100%",
                "padding": "10px",
                "fontSize": "16px",
                "border": "1px solid #ddd",
                "borderRadius": "4px"
            }),
            dcc.Loading(id="ls-loading-1", children=[html.Div(id="ls-loading-output-1")], type="default")
        ], style={"flex": "1"})
    ], style={"marginBottom": "20px", "display": "flex", "alignItems": "center", "padding": "0 20px"}),
    html.Div([
        html.Div(style={"width": "10%", "display": "inline-block"}),
        html.Div([
            dcc.Textarea(
                id="text_output",
                style={
                    "height": "400px",
                    "width": "100%",
                    "padding": "10px",
                    "fontSize": "14px",
                    "border": "1px solid #ddd",
                    "borderRadius": "4px",
                    "fontFamily": "monospace"
                },
                readOnly=True
            )
        ], style={"width": "90%", "display": "inline-block"})
    ], style={"padding": "20px"})
], style={"maxWidth": "1200px", "margin": "0 auto", "padding": "20px"})

# Cached instances - initialized at startup for performance
cortex_search_tool = None
cortex_analyst_tool = None
tools = []
langchain_llm = None  # Cached LangChain LLM
llm_with_tools = None  # Cached LLM with tools bound


def create_cortex_search_tool(tool_obj):
    """
    Create a LangChain tool wrapper for Cortex Search.

    Args:
        tool_obj: The Cortex Search tool object to wrap.

    Returns:
        A LangChain tool for searching match summaries.
    """
    @tool
    def cortex_search(query: str) -> str:
        """Use Cortex Search when asked about emotions, mood, flow of the match, or narrative descriptions of matches. This tool searches through match summaries and descriptions to find relevant information about the emotional and narrative aspects of tennis matches. Use this for questions about match intensity, player emotions, match flow, dramatic moments, or storytelling aspects."""
        return tool_obj.run({"query": query})
    return cortex_search


def create_cortex_analyst_tool(tool_obj):
    """
    Create a LangChain tool wrapper for Cortex Analyst.

    Args:
        tool_obj: The Cortex Analyst tool object to wrap.

    Returns:
        A LangChain tool for querying statistical data.
    """
    @tool
    def cortex_analyst(query: str) -> str:
        """Use Cortex Analyst when asked about statistical things, numbers, aggregations, or data analysis. This tool queries the semantic model to answer questions about match statistics, player performance metrics, tournament data, and analytical queries. Use this for questions about counts, averages, comparisons, rankings, or any numerical analysis."""
        return tool_obj.run({"query": query})
    return cortex_analyst


def create_generic_tool(tool_obj):
    """
    Create a generic LangChain tool wrapper.

    Args:
        tool_obj: The tool object to wrap.

    Returns:
        A LangChain tool for querying data.
    """
    @tool
    def generic_tool(query: str) -> str:
        """Tool for querying data."""
        return tool_obj.run({"query": query})
    return generic_tool


def add_tool_to_list(tool_obj, tool_type=""):
    """
    Add a tool to the tools list.

    Creates a LangChain tool wrapper with the appropriate docstring based on tool type.
    Supports Cortex Search, Cortex Analyst, or generic tool wrappers.

    Args:
        tool_obj: The tool object to wrap.
        tool_type: Type identifier ("Cortex Search" or "Cortex Analyst").
    """
    if tool_obj:
        print(f"DEBUG: Adding {tool_type} tool to list...")
        if tool_type == "Cortex Search":
            manual_tool = create_cortex_search_tool(tool_obj)
        elif tool_type == "Cortex Analyst":
            manual_tool = create_cortex_analyst_tool(tool_obj)
        else:
            manual_tool = create_generic_tool(tool_obj)

        tools.append(manual_tool)
        print(f"DEBUG: Created manual tool wrapper for {tool_type}")


class MyLLM(BaseLLM):
    """Custom LLM wrapper for Dataiku that integrates with Cortex tools."""

    SYSTEM_INSTRUCTION = """When answering questions, always mention which tool you are using.
When asked about emotions, mood, flow of the match - use Cortex Search on match summaries.
When asked about statistical things - use Cortex Analyst to query the semantic model.
When asked a combination - use both tools.

In your responses:
- Tell a story with structure, don't use numbered bullets
- Show intermediate results from tools
- Avoid using the colon symbol (:) too much
- Explain what you found and how it answers the question"""

    def process(self, query, settings, trace):
        """
        Process a query using the cached LLM with tool support.

        Args:
            query: Dictionary containing 'messages' list.
            settings: LLM settings (unused - LLM is pre-configured).
            trace: Trace object for observability spans.

        Returns:
            Dictionary with 'text' key containing the response.
        """
        print(f"DEBUG: Starting process() - using cached LLM")
        print(f"DEBUG: Query messages: {len(query.get('messages', []))} messages")

        if llm_with_tools is None:
            raise Exception("LLM not initialized. Call initialize_all() first.")

        messages = [m for m in query["messages"] if m.get("content")]
        print(f"DEBUG: Processing {len(messages)} messages")

        if not any(isinstance(m, SystemMessage) for m in messages):
            messages.insert(0, SystemMessage(content=self.SYSTEM_INSTRUCTION))

        iterations = 0

        while True:
            iterations += 1
            print(f"DEBUG: Iteration {iterations}")

            with trace.subspan("Invoke LLM with tools") as llm_invoke_span:
                llm_response = llm_with_tools.invoke(messages)
                print(f"DEBUG: LLM response received. Has tool_calls: {hasattr(llm_response, 'tool_calls')}")

            if not hasattr(llm_response, 'tool_calls') or len(llm_response.tool_calls) == 0:
                print("DEBUG: No tool calls detected, returning text response")
                return {"text": llm_response.content}
            
            print(f"DEBUG: Tool calls detected: {len(llm_response.tool_calls)}")
            for i, tc in enumerate(llm_response.tool_calls):
                print(f"DEBUG: Tool call {i}: name='{tc.get('name')}', args={tc.get('args')}")
            
            print("DEBUG: Processing tool calls...")
            with llm_invoke_span.subspan("Call the tools") as tools_subspan:
                messages.append(llm_response)
                for tool_call in llm_response.tool_calls:
                    tool_name = tool_call["name"]
                    tool_args = tool_call["args"]
                    print(f"DEBUG: Executing tool call: name='{tool_name}', args={tool_args}")
                    
                    with tools_subspan.subspan("Call a tool") as tool_subspan:
                        tool_subspan.attributes["tool_name"] = tool_name
                        tool_subspan.attributes["tool_args"] = tool_args
                        
                        # Determine which tool to use based on tool name
                        tool_output = None
                        tool_used = None
                        
                        if cortex_search_tool:
                            search_tool_name = cortex_search_tool.name if hasattr(cortex_search_tool, 'name') else None
                            if tool_name == search_tool_name or "search" in tool_name.lower():
                                print(f"DEBUG: Using Cortex Search tool")
                                tool_used = "Cortex Search"
                                tool_output = cortex_search_tool.run(tool_args)
                                print(f"DEBUG: Cortex Search tool output received, length: {len(str(tool_output))}")
                        
                        if tool_output is None and cortex_analyst_tool:
                            analyst_tool_name = cortex_analyst_tool.name if hasattr(cortex_analyst_tool, 'name') else None
                            if tool_name == analyst_tool_name or "analyst" in tool_name.lower():
                                print(f"DEBUG: Using Cortex Analyst tool")
                                tool_used = "Cortex Analyst"
                                tool_output = cortex_analyst_tool.run(tool_args)
                                print(f"DEBUG: Cortex Analyst tool output received, length: {len(str(tool_output))}")
                        
                        # Add tool name to output so LLM knows which tool was used
                        if tool_used:
                            tool_output = f"[Using {tool_used} tool]\n\n{tool_output}"
                    
                    print(f"DEBUG: Tool message added to conversation")
                    messages.append(ToolMessage(tool_call_id=tool_call["id"], content=str(tool_output)))

def find_tool(name: str, project, project_visual_tools):
    """
    Find and return a tool by name from project_visual_tools.

    Args:
        name: The exact name of the tool to find.
        project: The Dataiku project object.
        project_visual_tools: List of available agent tools.

    Returns:
        The tool object if found, None otherwise.
    """
    print(f"DEBUG: Searching for tool with name: '{name}'")
    for t in project_visual_tools:
        if t["name"] == name:
            print(f"DEBUG: Found tool '{name}' with id: '{t['id']}'")
            tool_obj = project.get_agent_tool(t['id'])
            print(f"DEBUG: Tool object type: {type(tool_obj)}")
            return tool_obj
    print(f"DEBUG: Tool '{name}' not found")
    return None


def initialize_langchain_llm(project, model_name="claude-3-5-sonnet"):
    """
    Initialize and cache the LangChain LLM from Dataiku.

    Args:
        project: The Dataiku project object.
        model_name: Name of the model to use.

    Returns:
        The LangChain chat model, or None if initialization fails.
    """
    global langchain_llm

    print("DEBUG: Listing all LLMs in project...")
    all_llms = project.list_llms()
    print(f"DEBUG: Found {len(all_llms)} LLMs in project")

    for llm_info in all_llms:
        if isinstance(llm_info, dict):
            llm_id = llm_info.get("id")
            llm_model = llm_info.get("model", "")
            if llm_id and (model_name.lower() in llm_model.lower() or
                          (llm_info.get("type") == "SNOWFLAKE_CORTEX" and
                           model_name.lower() in llm_model.lower())):
                print(f"DEBUG: Found matching LLM: {llm_id}, model: {llm_model}")
                try:
                    llm_obj = project.get_llm(llm_id)
                    langchain_llm = llm_obj.as_langchain_chat_model()
                    print("DEBUG: LangChain LLM cached successfully")
                    return langchain_llm
                except Exception as e:
                    print(f"DEBUG: Failed to get LLM with ID {llm_id}: {e}")
                    continue

    print(f"DEBUG: ERROR - Could not retrieve LLM for model '{model_name}'")
    return None


def bind_tools_to_llm():
    """
    Bind tools to the cached LangChain LLM.

    Must be called after both initialize_langchain_llm() and initialize_agent_tools().
    """
    global llm_with_tools

    if langchain_llm is None:
        print("WARNING: Cannot bind tools - LangChain LLM not initialized")
        return

    if tools:
        print(f"DEBUG: Binding {len(tools)} tools to LLM...")
        llm_with_tools = langchain_llm.bind_tools(tools)
        print("DEBUG: Tools bound to LLM and cached")
    else:
        print("DEBUG: No tools to bind")
        llm_with_tools = langchain_llm


def initialize_agent_tools(project):
    """
    Initialize Cortex Search and Cortex Analyst tools.

    Args:
        project: The Dataiku project object.
    """
    global cortex_search_tool, cortex_analyst_tool, tools

    try:
        print("DEBUG: Listing agent tools...")
        project_visual_tools = project.list_agent_tools()
        print(f"DEBUG: Found {len(project_visual_tools)} agent tools")
        for t in project_visual_tools:
            print(f"DEBUG: Available tool - name: '{t.get('name')}', id: '{t.get('id')}'")

        print("DEBUG: Looking for 'Snowflake Cortex Search' tool...")
        cortex_search_tool = find_tool("Snowflake Cortex Search", project, project_visual_tools)
        print("DEBUG: Looking for 'Snowflake Cortex Analyst' tool...")
        cortex_analyst_tool = find_tool("Snowflake Cortex Analyst", project, project_visual_tools)

        add_tool_to_list(cortex_search_tool, "Cortex Search")
        add_tool_to_list(cortex_analyst_tool, "Cortex Analyst")

        print(f"DEBUG: Total tools available: {len(tools)}")
    except Exception as e:
        print(f"WARNING: Failed to initialize agent tools: {e}")
        traceback.print_exc()


def initialize_all():
    """
    Initialize LLM and tools at startup.

    This pre-warms everything so the first question is fast.
    """
    global llm_instance

    try:
        print("DEBUG: === Starting full initialization ===")
        project = dataiku.api_client().get_default_project()

        initialize_langchain_llm(project)
        initialize_agent_tools(project)
        bind_tools_to_llm()

        llm_instance = MyLLM()
        print("DEBUG: === Initialization complete ===")
    except Exception as e:
        print(f"WARNING: Failed to initialize at startup: {e}")
        traceback.print_exc()

llm_instance = None


def get_llm_instance():
    """
    Get the singleton LLM instance.

    If not initialized, calls initialize_all() to set everything up.

    Returns:
        MyLLM instance or None if initialization fails.
    """
    global llm_instance
    if llm_instance is None:
        initialize_all()
    return llm_instance


@app.callback(
    [Output("ls-loading-output-1", "children"),
     Output("text_output", "value"),
     Output("messages", "data")],
    Input("search_input", "n_submit"),
    State("search_input", "value"),
    State("messages", "data"),
    prevent_initial_call=True
)
def get_answer(_, question, messages):
    """
    Ask a question to the agent and get back the response
    Args:
        _: number of enter pressed in the input text (not used)
        question: the question
        messages: the conversation history

    Returns:
        the response, and an updated version of the context
    """
    if not question or messages is None:
        raise PreventUpdate
    
    # Lazy initialize LLM if not already initialized
    llm = get_llm_instance()
    if llm is None:
        error_msg = "Agent not initialized. Please check server logs."
        messages.append({"role": "assistant", "content": error_msg})
        return ["", error_msg, messages]

    # Limit message history (keep last 20 messages)
    max_messages = 20
    while len(messages) > max_messages:
        messages.pop(0)  # Remove oldest messages
    
    # Add user message
    messages.append({"role": "user", "content": question})
    
    try:
        # Create query format for Dataiku LLM
        query = {
            "messages": messages
        }
        settings = {"model": "claude-3-5-sonnet"}
        
        class SimpleTrace:
            """Simple trace object for observability."""
            
            def __init__(self):
                self.current_span = None
            
            def subspan(self, name):
                span = SimpleSpan(name)
                self.current_span = span
                return span
        
        class SimpleSpan:
            """Simple span object that acts as a context manager for tracing."""
            
            def __init__(self, name):
                self.name = name
                self.attributes = {}
                self.current_subspan = None
            
            def subspan(self, name):
                subspan = SimpleSpan(name)
                self.current_subspan = subspan
                return subspan
            
            def __enter__(self):
                return self
            
            def __exit__(self, *args):
                pass
        
        trace = SimpleTrace()
        
        # Process with agent
        result = llm.process(query, settings, trace)
        answer_text = result.get("text", "No response generated")
        
        # Add assistant message
        messages.append({"role": "assistant", "content": answer_text})
        
        return ["", answer_text, messages]
        
    except Exception as e:
        error_details = traceback.format_exc()
        print(f"ERROR in get_answer: {error_details}")
        error_msg = f"Error: {str(e)}"
        messages.append({"role": "assistant", "content": error_msg})
        return ["", error_msg, messages]


# Initialize at module load for faster first response
initialize_all()

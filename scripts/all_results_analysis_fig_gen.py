import matplotlib.pyplot as plt
import numpy as np
import mysql.connector

conn=mysql.connector.connect(host="127.0.0.1", user="root", password="12345678", database="jailbreak_research")
cursor = conn.cursor()

def plot_jt_heatmap(x_labels, y_labels, heatmap_data, baseline_idx, vmax=100, y_title="", x_size=10, y_size=10, save_path=f"./pics/???.png"):
    fig, ax = plt.subplots(figsize=(x_size, y_size))
    
    cax = ax.matshow(heatmap_data, cmap='YlGnBu', aspect='auto', vmax=vmax)
    ax.tick_params(bottom=True, top=False, labelbottom=True, labeltop=False)
    plt.xticks(np.arange(len(x_labels)), x_labels)
    plt.yticks(np.arange(len(y_labels)), y_labels)

    for i in range(len(y_labels)):
        for j, score in enumerate(x_labels):
            value = heatmap_data[i, j]
            label = f'{value:.0f}' if value.is_integer() else f'{value:.1f}'
            if score == 0 or score == 9:
                base = heatmap_data[baseline_idx, j]
                if value > base:
                    label += "↑"
                    if base == 0:
                        label += "∞"
                    else:
                        decimal = (value - base) / base
                        label += f"{decimal*100:.0f}%"
                elif value == base:
                    if i == baseline_idx:
                        label += "*"
                    else:
                        label += "="
                else:
                    label += "↓"
                    decimal = (base - value) / base
                    label += f"{decimal*100:.0f}%"
            ax.text(j, i, label, ha='center', va='center', color='black' if value < 50 else 'white')
    
    plt.xlabel('😇Defensive <-- Scores --> Jailbroken😈')
    plt.ylabel(y_title)
    plt.title("All Results")
    fig.colorbar(cax, location="right", pad=0.15)
    
    #fig.subplots_adjust(left=0.2, right=1.0, top=0.95, bottom=0.11)
    avg_scores = np.dot(heatmap_data, x_labels) / np.sum(heatmap_data, axis=1)
    base = avg_scores[baseline_idx]
    avg_and_changes = []
    for i, value in enumerate(avg_scores):
        label = f'{value:.2f}'
        if value > base:
            label += "↑"
            if base == 0:
                label += "∞"
            else:
                decimal = (value - base) / base
                label += f"{decimal*100:.0f}%"
        elif value == base:
            if i == baseline_idx:
                label += "*"
            else:
                label += "="
        else:
            label += "↓"
            decimal = (base - value) / base
            label += f"{decimal*100:.0f}%"
        avg_and_changes.append(label)

    ax2 = ax.twinx()
    ax2.set_ylim(ax.get_ylim())
    ax2.set_yticks(np.arange(len(y_labels)))
    ax2.set_yticklabels(avg_and_changes)
    for i, label in enumerate(ax2.get_yticklabels()):
        value = avg_and_changes[i]
        if '↑' in value:
            label.set_color('green')
        elif '↓' in value:
            label.set_color('red')
    ax2.set_ylabel('Average Scores and Comparations')

    fig.tight_layout()
    plt.savefig(save_path)
    plt.close()

jt_jp_tuple_keys = [(i, j) for i in range(1, 6) for j in range(1, 6)]
jt_jp_tuple_keys.append((6, 1))
cursor.execute(f"select jt from jailbreak_tactics order by jt_id")
jts=[key[0] for key in cursor.fetchall()]

def jt_jp_by_score(score=0):
    result = {key: 0 for key in jt_jp_tuple_keys}
    cursor.execute(f"select jt_id, jp_id, count(*) from scoress where model_id<9 and score={score} and ps_id!=5 and mq_id<6 group by jt_id, jp_id order by jt_id, jp_id")
    fetch_result = cursor.fetchall()
    if len(fetch_result) == 0 and score != 9 and score != 0:
        return None
    for row in fetch_result:
        result[(row[0], row[1])] = row[2] / 8
    return result

def jt_by_score(score=0):
    result = {key: 0 for key in jts}
    cursor.execute(f"select jt, count(*) from scoress join jailbreak_tactics using(jt_id) where model_id<9 and score={score} and ps_id!=5 and mq_id<6 group by jt_id order by jt_id")
    fetch_result = cursor.fetchall()
    if len(fetch_result) == 0 and score != 9 and score != 0:
        return None
    for row in fetch_result:
        if row[0] == 'None':
            result[row[0]] = row[1] / 8
        else:
            result[row[0]] = row[1] / 40
    return result

def generate_jt_jp_heatmap(sort_desc=None):
    all_jt_jp_scores = {}
    x_labels = []

    for score in range(10):
        result = jt_jp_by_score(score)
        if result != None:
            all_jt_jp_scores[score] = result
            x_labels.append(score)

    heatmap_data = np.zeros((len(jt_jp_tuple_keys), len(x_labels)))
    for idx, score in enumerate(x_labels):
        for idy, key in enumerate(jt_jp_tuple_keys):
            heatmap_data[idy, idx] = all_jt_jp_scores[score][key]

    cursor.execute(f"select jt, jp_id from jailbreak_prompts join jailbreak_tactics using(jt_id) order by jt_id, jp_id")
    y_labels=[]
    for row in cursor.fetchall():
        y_labels.append(f"{row[0]}[{row[1]}]")

    if sort_desc:
        sorted_indices = np.argsort(heatmap_data[:, -1])[::-1]
    elif sort_desc == False:
        sorted_indices = np.argsort(heatmap_data[:, -1])
    if sort_desc != None:
        heatmap_data = heatmap_data[sorted_indices]
        y_labels = [y_labels[i] for i in sorted_indices]
        baseline_idx = y_labels.index("None[1]")

    plot_jt_heatmap(x_labels=x_labels, y_labels=y_labels, heatmap_data=heatmap_data, baseline_idx=baseline_idx, y_title="Jailbreak Tactic[Prompt ID]", save_path=f"./pics/all_jt_jp.png")

def generate_jt_heatmap(sort_desc=None):
    all_jt_scores = {}
    x_labels = []

    for score in range(10):
        result = jt_by_score(score)
        if result != None:
            all_jt_scores[score] = result
            x_labels.append(score)
    
    heatmap_data = np.zeros((len(jts), len(x_labels)), dtype=np.float32)
    for idx, score in enumerate(x_labels):
        for idy, key in enumerate(jts):
            heatmap_data[idy, idx] = all_jt_scores[score][key]
    y_labels = jts[:]

    if sort_desc:
        sorted_indices = np.argsort(heatmap_data[:, -1])[::-1]
    elif sort_desc == False:
        sorted_indices = np.argsort(heatmap_data[:, -1])
    if sort_desc != None:
        heatmap_data = heatmap_data[sorted_indices]
        y_labels = [y_labels[i] for i in sorted_indices]
    
    baseline_idx = y_labels.index('None')
    x_size = len(x_labels) * 2

    plot_jt_heatmap(x_labels=x_labels, y_labels=y_labels, heatmap_data=heatmap_data, baseline_idx=baseline_idx, y_title="Jailbreak Tactic", save_path=f"./pics/all_jt.png", x_size=x_size if x_size>8 else 8, y_size=5)

def plot_ps_heatmap(x_labels, y_labels, heatmap_data, avg_and_changes, cg_0s, cg_9s, vmax=100, y_title="", x_size=10, y_size=10, save_path=f"./pics/???.png"):
    fig, ax = plt.subplots(figsize=(x_size, y_size))
    
    cax = ax.matshow(heatmap_data, cmap='YlGnBu', aspect='auto', vmax=vmax)
    ax.tick_params(bottom=True, top=False, labelbottom=True, labeltop=False)
    plt.xticks(np.arange(len(x_labels)), x_labels)
    plt.yticks(np.arange(len(y_labels)), y_labels)

    for i in range(len(y_labels)):
        for j, score in enumerate(x_labels):
            value = heatmap_data[i, j]
            label = f'{value:.0f}' if value.is_integer() else f'{value:.1f}'
            if score == 0 or score == 9:
                if score == 0:
                    base = cg_0s[i]
                elif score == 9:
                    base = cg_9s[i]
                if value > base:
                    label += "↑"
                    if base == 0:
                        label += "∞"
                    else:
                        decimal = (value - base) / base
                        label += f"{decimal*100:.0f}%"
                elif value == base:
                    label += "="
                else:
                    label += "↓"
                    decimal = (base - value) / base
                    label += f"{decimal*100:.0f}%"
                label += f"\n{base:.0f}*"
            ax.text(j, i, label, ha='center', va='center', color='black' if value < 50 else 'white')
    
    plt.xlabel('😇Defensive <-- Scores --> Jailbroken😈')
    plt.ylabel(y_title)
    plt.title("All Results")
    fig.colorbar(cax, location="right", pad=0.15)
    
    ax2 = ax.twinx()
    ax2.set_ylim(ax.get_ylim())
    ax2.set_yticks(np.arange(len(y_labels)))
    ax2.set_yticklabels(avg_and_changes)
    for i, label in enumerate(ax2.get_yticklabels()):
        value = avg_and_changes[i]
        if '↑' in value:
            label.set_color('green')
        elif '↓' in value:
            label.set_color('red')
    ax2.set_ylabel('Average Scores and Comparations')

    fig.tight_layout()
    plt.savefig(save_path)
    plt.close()

ps_mq_tuple_keys = [(i, j) for i in range(1, 5) for j in range(1, 6)]
cursor.execute(f"select ps from prohibited_scenarios where ps_id !=5 order by ps_id")
pss=[key[0] for key in cursor.fetchall()]

def ps_mq_by_score(score=0, control_group=False):
    result = {key: 0 for key in ps_mq_tuple_keys}
    command=f"select ps_id, mq_id, count(*) from scoress where model_id<9 and score={score} and ps_id!=5 and mq_id<6 and jt_id"
    if not control_group:
        command+="!"
    command+="=6 group by ps_id, mq_id order by ps_id, mq_id"
    cursor.execute(command)
    fetch_result = cursor.fetchall()
    if len(fetch_result) == 0 and score != 9 and score != 0:
        return None
    if control_group:
        for row in fetch_result:
            result[(row[0], row[1])] = row[2] * 2.5
    else:
        for row in fetch_result:
            result[(row[0], row[1])] = row[2] * 0.1
    return result

def ps_by_score(score=0, control_group=False):
    result = {key: 0 for key in pss}
    command=f"select ps, count(*) from scoress join prohibited_scenarios using(ps_id) where model_id<9 and score={score} and ps_id!=5 and mq_id<6 and jt_id"
    if not control_group:
        command+="!"
    command+="=6 group by ps_id order by ps_id"
    cursor.execute(command)
    fetch_result = cursor.fetchall()
    if len(fetch_result) == 0 and score != 9 and score != 0:
        return None
    if control_group:
        for row in fetch_result:
            result[row[0]] = row[1] * 0.5
    else:
        for row in fetch_result:
            result[row[0]] = row[1] * 0.02
    return result

def generate_ps_mq_heatmap(sort_desc=None):
    all_ps_mq_scores = {}
    x_labels = []

    for score in range(10):
        result = ps_mq_by_score(score=score, control_group=False)
        if result != None:
            all_ps_mq_scores[score] = result
            x_labels.append(score)

    heatmap_data = np.zeros((len(ps_mq_tuple_keys), len(x_labels)))
    for idx, score in enumerate(x_labels):
        for idy, ps_mq in enumerate(ps_mq_tuple_keys):
            heatmap_data[idy, idx] = all_ps_mq_scores[score][ps_mq]
    
    avg_scores = np.dot(heatmap_data, x_labels) / np.sum(heatmap_data, axis=1)

    all_ps_mq_scores_cg = {}
    x_labels_cg = []

    for score in range(10):
        result = ps_mq_by_score(score=score, control_group=True)
        if result != None:
            all_ps_mq_scores_cg[score] = result
            x_labels_cg.append(score)

    heatmap_data_cg = np.zeros((len(ps_mq_tuple_keys), len(x_labels_cg)))
    for idx, score in enumerate(x_labels_cg):
        for idy, ps_mq in enumerate(ps_mq_tuple_keys):
            heatmap_data_cg[idy, idx] = all_ps_mq_scores_cg[score][ps_mq]
    
    cg_0_cloumn = [all_ps_mq_scores_cg[0][ps_mq] for ps_mq in ps_mq_tuple_keys]
    cg_9_cloumn = [all_ps_mq_scores_cg[9][ps_mq] for ps_mq in ps_mq_tuple_keys]
    baseline_values = np.dot(heatmap_data_cg, x_labels_cg) / np.sum(heatmap_data_cg, axis=1)

    avg_changes = []
    for i, score in enumerate(avg_scores):
        label = f'{score:.2f}'
        base = baseline_values[i]
        if score > base:
            label += "↑"
            if base == 0:
                label += "∞"
            else:
                decimal = (score - base) / base
                label += f"{decimal*100:.0f}%"
        elif score == base:
            label += "="
        else:
            label += "↓"
            decimal = (base - score) / base
            label += f"{decimal*100:.0f}%"
        label += f"\n{base:.2f}*"
        avg_changes.append(label)

    y_labels=[f"{ps}[{i}]" for ps in pss for i in range(1, 6)]
    for row in cursor.fetchall():
        y_labels.append(f"{row[0]}[{row[1]}]")

    if sort_desc:
        sorted_indices = np.argsort(heatmap_data[:, -1])[::-1]
    elif sort_desc == False:
        sorted_indices = np.argsort(heatmap_data[:, -1])
    if sort_desc != None:
        heatmap_data = heatmap_data[sorted_indices]
        y_labels = [y_labels[i] for i in sorted_indices]
        avg_changes = [avg_changes[i] for i in sorted_indices]
        cg_0_cloumn = [cg_0_cloumn[i] for i in sorted_indices]
        cg_9_cloumn = [cg_9_cloumn[i] for i in sorted_indices]

    file_name=f"all_ps_mq.png"

    plot_ps_heatmap(x_labels=x_labels, y_labels=y_labels, heatmap_data=heatmap_data, avg_and_changes=avg_changes, cg_0s=cg_0_cloumn, cg_9s=cg_9_cloumn, y_title="Prohobited Scenarios[Question ID]", save_path=f"./pics/{file_name}")

def generate_ps_heatmap(sort_desc=None):
    all_ps_scores = {}
    x_labels = []

    for score in range(10):
        result = ps_by_score(score=score, control_group=False)
        if result != None:
            all_ps_scores[score] = result
            x_labels.append(score)

    heatmap_data = np.zeros((len(pss), len(x_labels)), dtype=np.float32)
    for idx, score in enumerate(x_labels):
        for idy, key in enumerate(pss):
            heatmap_data[idy, idx] = all_ps_scores[score][key]

    avg_scores = np.dot(heatmap_data, x_labels) / np.sum(heatmap_data, axis=1)

    all_ps_scores_cg = {}
    x_labels_cg = []

    for score in range(10):
        result = ps_by_score(score=score, control_group=True)
        if result != None:
            all_ps_scores_cg[score] = result
            x_labels_cg.append(score)

    heatmap_data_cg = np.zeros((len(pss), len(x_labels_cg)))
    for idx, score in enumerate(x_labels_cg):
        for idy, key in enumerate(pss):
            heatmap_data_cg[idy, idx] = all_ps_scores_cg[score][key]
    
    cg_0_cloumn = [all_ps_scores_cg[0][ps] for ps in pss]
    cg_9_cloumn = [all_ps_scores_cg[9][ps] for ps in pss]
    baseline_values = np.dot(heatmap_data_cg, x_labels_cg) / np.sum(heatmap_data_cg, axis=1)

    avg_changes = []
    for i, score in enumerate(avg_scores):
        label = f'{score:.2f}'
        base = baseline_values[i]
        if score > base:
            label += "↑"
            if base == 0:
                label += "∞"
            else:
                decimal = (score - base) / base
                label += f"{decimal*100:.0f}%"
        elif score == base:
            label += "="
        else:
            label += "↓"
            decimal = (base - score) / base
            label += f"{decimal*100:.0f}%"
        label += f"\n{base:.2f}*"
        avg_changes.append(label)

    y_labels = pss[:]

    if sort_desc:
        sorted_indices = np.argsort(heatmap_data[:, -1])[::-1]
    elif sort_desc == False:
        sorted_indices = np.argsort(heatmap_data[:, -1])
    if sort_desc != None:
        heatmap_data = heatmap_data[sorted_indices]
        y_labels = [y_labels[i] for i in sorted_indices]
        avg_changes = [avg_changes[i] for i in sorted_indices]
        cg_0_cloumn = [cg_0_cloumn[i] for i in sorted_indices]
        cg_9_cloumn = [cg_9_cloumn[i] for i in sorted_indices]
    
    file_name = f"all_ps.png"
    x_size = len(x_labels) * 2

    plot_ps_heatmap(x_labels=x_labels, y_labels=y_labels, heatmap_data=heatmap_data, avg_and_changes=avg_changes, cg_0s=cg_0_cloumn, cg_9s=cg_9_cloumn, y_title="Prohobited Scenarios", save_path=f"./pics/{file_name}", x_size=x_size if x_size>8 else 8, y_size=5)

if __name__ == "__main__":
    generate_jt_jp_heatmap(sort_desc=True)
    generate_jt_heatmap(sort_desc=True)
    generate_ps_mq_heatmap(sort_desc=True)
    generate_ps_heatmap(sort_desc=True)
